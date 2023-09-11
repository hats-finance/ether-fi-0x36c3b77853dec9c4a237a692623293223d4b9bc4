// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IStakingManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IeETH.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IRegulationsManager.sol";
import "./interfaces/IMembershipManager.sol";
import "./interfaces/ITNFT.sol";
import "./interfaces/IWithdrawRequestNFT.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IEtherFiAdmin.sol";

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, ILiquidityPool {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IStakingManager public stakingManager;
    IEtherFiNodesManager public nodesManager;
    IRegulationsManager public regulationsManager;
    IMembershipManager public membershipManager;
    ITNFT public tNft;
    IeETH public eETH; 

    bool public eEthliquidStakingOpened;

    uint128 public totalValueOutOfLp;
    uint128 public totalValueInLp;

    address public DEPRECATED_admin;

    uint32 public numPendingDeposits; // number of deposits to the staking manager, which needs 'registerValidator'
    
    address public DEPRECATED_bNftTreasury;
    IWithdrawRequestNFT public withdrawRequestNFT;

    BnftHolder[] public bnftHolders;
    uint128 public max_validators_per_owner;
    uint128 public schedulingPeriodInSeconds;
    
    HoldersUpdate public holdersUpdate;

    mapping(address => bool) public admins;
    mapping(SourceOfFunds => FundStatistics) public fundStatistics;
    mapping(uint256 => bytes32) public depositDataRootForApprovalDeposits;
    address public etherFiAdminContract;
    bool public whitelistEnabled;
    mapping(address => bool) public whitelisted;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, address recipient, uint256 amount);
    event UpdatedWhitelist(address userAddress, bool value);
    event BnftHolderDeregistered(address user, uint256 index);
    event BnftHolderRegistered(address user);
    event UpdatedSchedulingPeriod(uint128 newPeriodInSeconds);
    event BatchRegisteredAsBnftHolder(uint256 validatorId, bytes signature, bytes pubKey, bytes32 depositRoot);
    event StakingTargetWeightsSet(uint128 eEthWeight, uint128 etherFanWeight);
    event FundsDeposited(SourceOfFunds source, uint256 amount);
    event FundsWithdrawn(SourceOfFunds source, uint256 amount);
    event Rebase(uint256 totalEthLocked, uint256 totalEEthShares);
    event WhitelistStatusUpdated(bool value);

    error InvalidAmount();
    error DataNotSet();
    error InsufficientLiquidity();

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        require(totalValueOutOfLp >= msg.value, "rebase first before collecting the rewards");
        if (msg.value > type(uint128).max) revert InvalidAmount();
        totalValueOutOfLp -= uint128(msg.value);
        totalValueInLp += uint128(msg.value);
    }

    function initialize(address _regulationsManager) external initializer NonZeroAddress(_regulationsManager) {
        __Ownable_init();
        __UUPSUpgradeable_init();
        regulationsManager = IRegulationsManager(_regulationsManager);
        eEthliquidStakingOpened = false;
    }

    function initializePhase2() external onlyOwner {        
        fundStatistics[SourceOfFunds.EETH].numberOfValidators = 1;
        fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators = 1;
    }

    function deposit(address _user, bytes32[] calldata _merkleProof) external payable returns (uint256) {
        return deposit(_user, _user, _merkleProof);
    }

    /// @notice deposit into pool
    /// @dev mints the amount of eETH 1:1 with ETH sent
    function deposit(address _user, address _recipient, bytes32[] calldata _merkleProof) public payable returns (uint256) {
        if(msg.sender == address(membershipManager)) {
            if (_user != address(membershipManager)) {
                _isWhitelistedAndEligible(_user, _merkleProof);
            }       
            emit FundsDeposited(SourceOfFunds.ETHER_FAN, msg.value);
        } else {
            require(eEthliquidStakingOpened, "Liquid staking functions are closed");
            _isWhitelistedAndEligible(msg.sender, _merkleProof);
            emit FundsDeposited(SourceOfFunds.EETH, msg.value);
        }
        require(_recipient == msg.sender || _recipient == address(membershipManager), "Wrong Recipient");
        
        totalValueInLp += uint128(msg.value);
        uint256 share = _sharesForDepositAmount(msg.value);
        if (msg.value > type(uint128).max || msg.value == 0 || share == 0) revert InvalidAmount();

        eETH.mintShares(_recipient, share);

        emit Deposit(_recipient, msg.value);

        return share;
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to the recipient
    /// @param _recipient the recipient who will receives the ETH
    /// @param _amount the amount to withdraw from contract
    /// it returns the amount of shares burned
    function withdraw(address _recipient, uint256 _amount) external onlyWithdrawRequestOrMembershipManager NonZeroAddress(_recipient) returns (uint256) {

        if(totalValueInLp < _amount || eETH.balanceOf(msg.sender) < _amount) revert InsufficientLiquidity();

        uint256 share = sharesForWithdrawalAmount(_amount);
        totalValueInLp -= uint128(_amount);
        if (_amount > type(uint128).max || _amount == 0 || share == 0) revert InvalidAmount();

        if(msg.sender == address(membershipManager)) {
            emit FundsWithdrawn(SourceOfFunds.ETHER_FAN, _amount);
        } else {
            emit FundsWithdrawn(SourceOfFunds.EETH, _amount);
        }

        eETH.burnShares(msg.sender, share);

        (bool sent, ) = _recipient.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        emit Withdraw(msg.sender, _recipient, _amount);
        return share;
    }

    /// @notice request withdraw from pool and receive a WithdrawRequestNFT
    /// @dev Transfers the amount of eETH from msg.senders account to the WithdrawRequestNFT contract & mints an NFT to the msg.sender
    /// @param recipient the recipient who will be issued the NFT
    /// @param amount the requested amount to withdraw from contract
    function requestWithdraw(address recipient, uint256 amount) public whenLiquidStakingOpen NonZeroAddress(recipient) returns (uint256) {

        if(totalValueInLp < amount || eETH.balanceOf(recipient) < amount) revert InsufficientLiquidity();

        uint256 share = sharesForAmount(amount);
        if (amount > type(uint128).max || amount == 0 || share == 0) revert InvalidAmount();

        uint256 requestId = withdrawRequestNFT.requestWithdraw(uint96(amount), uint96(share), recipient);
        // transfer shares to WithdrawRequestNFT contract from this contract
        eETH.transferFrom(recipient, address(withdrawRequestNFT), amount);
        return requestId;
    }

    function requestWithdrawWithPermit(address _owner, uint256 _amount, PermitInput calldata _permit)
        external
        returns (uint256)
    {
        eETH.permit(msg.sender, address(this), _permit.value, _permit.deadline, _permit.v, _permit.r, _permit.s);
        return requestWithdraw(_owner, _amount);
    }

    function requestMembershipNFTWithdraw(address recipient, uint256 amount) public whenLiquidStakingOpen NonZeroAddress(recipient) returns (uint256) {
        require(totalValueInLp >= amount, "Not enough ETH in the liquidity pool");

        uint256 share = sharesForAmount(amount);
        if (amount > type(uint128).max || amount == 0 || share == 0) revert InvalidAmount();

        uint256 requestId = withdrawRequestNFT.requestWithdraw(uint96(amount), uint96(share), recipient);
        // transfer shares to WithdrawRequestNFT contract
        eETH.transferFrom(msg.sender, address(withdrawRequestNFT), amount);
        return requestId;
    }

    function batchDepositAsBnftHolder(uint256[] calldata _candidateBidIds, uint256 _index, uint256 _numberOfValidators) external payable returns (uint256[] memory){
        (uint256 firstIndex, uint128 lastIndex, uint128 lastIndexNumOfValidators) = dutyForWeek();
        _isAssigned(firstIndex, lastIndex, _index);
        require(msg.sender == bnftHolders[_index].holder, "Incorrect Caller");
        require(bnftHolders[_index].timestamp < uint32(_getCurrentSchedulingStartTimestamp()), "Already deposited");

        if(_index == lastIndex) {
            require(_numberOfValidators <= lastIndexNumOfValidators, "Above max allocation");
        } else {
            require(_numberOfValidators <= max_validators_per_owner, "Above max allocation");
        }

        SourceOfFunds _source = _allocateSourceOfFunds();

        if(_source == SourceOfFunds.EETH){
            fundStatistics[SourceOfFunds.EETH].numberOfValidators += uint32(_numberOfValidators);
        } else {
            fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators += uint32(_numberOfValidators);
        }

        require(msg.value == _numberOfValidators * 2 ether, "B-NFT holder must deposit 2 ETH per validator");
        require(totalValueInLp + msg.value >= 32 ether * _numberOfValidators, "Not enough balance");

        uint256 amountFromLp = 30 ether * _numberOfValidators;
        if (amountFromLp > type(uint128).max) revert InvalidAmount();

        totalValueOutOfLp += uint128(amountFromLp);
        totalValueInLp -= uint128(amountFromLp);
        numPendingDeposits += uint32(_numberOfValidators);

        bnftHolders[_index].timestamp = uint32(block.timestamp);

        uint256[] memory newValidators = stakingManager.batchDepositWithBidIds{value: 32 ether * _numberOfValidators}(_candidateBidIds, msg.sender, _source, false); // TODO(Dave) how do players decide restaking or not
        if (_numberOfValidators > newValidators.length) {
            uint256 returnAmount = 2 ether * (_numberOfValidators - newValidators.length);
            totalValueOutOfLp += uint128(returnAmount);
            totalValueInLp -= uint128(returnAmount);

            (bool sent, ) = msg.sender.call{value: returnAmount}("");
            require(sent, "Failed to send Ether");
        }
        
        return newValidators;
    }

    //  _registerValidatorDepositData takes in:
    //  publicKey: 
    //  signature: signature for 1 ether deposit
    //  depositDataRoot: data root for 31 ether deposit
    //  ipfsHashForEncryptedValidatorKey:
    function batchRegisterAsBnftHolder(
        bytes32 _depositRoot,
        uint256[] calldata _validatorIds,
        IStakingManager.DepositData[] calldata _registerValidatorDepositData,
        bytes32[] calldata _depositDataRootApproval,
        bytes[] calldata _signaturesForApprovalDeposit
    ) external {
        require(_validatorIds.length == _registerValidatorDepositData.length, "Array lengths must match");

        numPendingDeposits -= uint32(_validatorIds.length);
        stakingManager.batchRegisterValidators(_depositRoot, _validatorIds, msg.sender, address(this), _registerValidatorDepositData, msg.sender);
        
        for(uint256 x; x < _validatorIds.length; x++) {
            depositDataRootForApprovalDeposits[_validatorIds[x]] = _depositDataRootApproval[x];
            emit BatchRegisteredAsBnftHolder(_validatorIds[x], _signaturesForApprovalDeposit[x], _registerValidatorDepositData[x].publicKey, _depositDataRootApproval[x]);
        }
    }

    function batchCancelDeposit(uint256[] calldata _validatorIds) external {
        uint256 returnAmount = 2 ether * _validatorIds.length;

        totalValueOutOfLp += uint128(returnAmount);
        numPendingDeposits -= uint32(_validatorIds.length);

        stakingManager.batchCancelDepositAsBnftHolder(_validatorIds, msg.sender);

        totalValueInLp -= uint128(returnAmount);

        (bool sent, ) = address(msg.sender).call{value: returnAmount}("");
        require(sent, "Failed to send Ether");
    }

    function registerAsBnftHolder(address _user) public onlyAdmin {
        _checkHoldersUpdateStatus();
        BnftHolder memory bnftHolder = BnftHolder({
            holder: _user,
            timestamp: 0
        });

        bnftHolders.push(bnftHolder);

        emit BnftHolderRegistered(msg.sender);
    }


    function fixData() public onlyAdmin {
        delete bnftHolders;
    }

    function addHolders() public {
        registerAsBnftHolder(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        registerAsBnftHolder(0xD0d7F8a5a86d8271ff87ff24145Cf40CEa9F7A39);
        registerAsBnftHolder(0x6f6C30D101c3FDa90546C0eA829726801A887b3f);
    }

    function deRegisterBnftHolder(uint256 _index) external {
        require(admins[msg.sender] || msg.sender == bnftHolders[_index].holder, "Incorrect Caller");
        require(_index < bnftHolders.length, "Invalid index");

        address holder = bnftHolders[_index].holder;

        bnftHolders[_index] = bnftHolders[bnftHolders.length - 1];
        bnftHolders.pop();

        emit BnftHolderDeregistered(holder, _index);
    }

    function dutyForWeek() public view returns (uint256, uint128, uint128) {
        uint128 maxValidatorsPerOwner = max_validators_per_owner;

        if((maxValidatorsPerOwner == 0) || (schedulingPeriodInSeconds == 0) || (etherFiAdminContract == address(0)) || (IEtherFiAdmin(etherFiAdminContract).numValidatorsToSpinUp() == 0)) {
            revert DataNotSet();
        }

        uint128 lastIndex;
        uint128 lastIndexNumberOfValidators = maxValidatorsPerOwner;

        uint256 index = _getSlotIndex();
        uint128 numValidatorsToCreate = IEtherFiAdmin(etherFiAdminContract).numValidatorsToSpinUp();

        if(numValidatorsToCreate % maxValidatorsPerOwner == 0) {
            uint128 size = numValidatorsToCreate / maxValidatorsPerOwner;
            lastIndex = _fetchLastIndex(size, index);
        } else {
            uint128 size = (numValidatorsToCreate / maxValidatorsPerOwner) + 1;
            lastIndex = _fetchLastIndex(size, index);
            lastIndexNumberOfValidators = numValidatorsToCreate % maxValidatorsPerOwner;
        }

        return (index, lastIndex, lastIndexNumberOfValidators);
    }

    /// @notice Send the exit requests as the T-NFT holder
    function sendExitRequests(uint256[] calldata _validatorIds) external onlyAdmin {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            nodesManager.sendExitRequest(validatorId);
        }
    }

    /// @notice Allow interactions with the eEth token
    function updateLiquidStakingStatus(bool _value) external onlyAdmin {
        eEthliquidStakingOpened = _value;
    }

    /// @notice Rebase by ether.fi
    function rebase(int128 _accruedRewards) public {
        require(msg.sender == address(membershipManager), "only membership manager can rebase");
        totalValueOutOfLp = uint128(int128(totalValueOutOfLp) + _accruedRewards);

        emit Rebase(getTotalPooledEther(), eETH.totalShares());
    }

    /// @notice swap T-NFTs for ETH
    /// @param _tokenIds the token Ids of T-NFTs
    function swapTNftForEth(uint256[] calldata _tokenIds) external onlyOwner {
        require(totalValueInLp >= 30 ether * _tokenIds.length, "not enough ETH in LP");
        uint128 amount = uint128(30 ether * _tokenIds.length);
        totalValueOutOfLp += amount;
        totalValueInLp -= amount;
        address owner = owner();
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tNft.transferFrom(owner, address(this), _tokenIds[i]);
        }
        (bool sent, ) = address(owner).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice sets the contract address for eETH
    /// @param _eETH address of eETH contract
    function setTokenAddress(address _eETH) external onlyOwner NonZeroAddress(_eETH) {
        eETH = IeETH(_eETH);
    }

    function setStakingManager(address _address) external onlyOwner NonZeroAddress(_address) {
        stakingManager = IStakingManager(_address);
    }

    function setEtherFiNodesManager(address _nodeManager) public onlyOwner NonZeroAddress(_nodeManager) {
        nodesManager = IEtherFiNodesManager(_nodeManager);
    }

    function setMembershipManager(address _address) external onlyOwner NonZeroAddress(_address) {
        membershipManager = IMembershipManager(_address);
    }

    function setTnft(address _address) external onlyOwner NonZeroAddress(_address) {
        tNft = ITNFT(_address);
    }

    function setEtherFiAdminContract(address _address) external onlyOwner NonZeroAddress(_address) {
        etherFiAdminContract = _address;
    }

    function setWithdrawRequestNFT(address _address) external onlyOwner NonZeroAddress(_address) {
        withdrawRequestNFT = IWithdrawRequestNFT(_address);
    }

    /// @notice Updates the address of the admin
    /// @param _address the new address to set as admin
    function updateAdmin(address _address, bool _isAdmin) external onlyOwner NonZeroAddress(_address) {
        admins[_address] = _isAdmin;
    }

    function setMaxBnftSlotSize(uint128 _newSize) external onlyAdmin {
        max_validators_per_owner = _newSize;
    }

    function setSchedulingPeriodInSeconds(uint128 _schedulingPeriodInSeconds) external onlyAdmin {
        schedulingPeriodInSeconds = _schedulingPeriodInSeconds;

        emit UpdatedSchedulingPeriod(_schedulingPeriodInSeconds);
    }

    function numberOfActiveSlots() public view returns (uint32 numberOfActiveSlots) {
        numberOfActiveSlots = uint32(bnftHolders.length);
        if(holdersUpdate.timestamp > uint32(_getCurrentSchedulingStartTimestamp())) {
            numberOfActiveSlots = holdersUpdate.startOfSlotNumOwners;
        }
    }

    function setStakingTargetWeights(uint32 _eEthWeight, uint32 _etherFanWeight) external onlyAdmin {
        require(_eEthWeight + _etherFanWeight == 100, "Invalid weights");

        fundStatistics[SourceOfFunds.EETH].targetWeight = _eEthWeight;
        fundStatistics[SourceOfFunds.ETHER_FAN].targetWeight = _etherFanWeight;

        emit StakingTargetWeightsSet(_eEthWeight, _etherFanWeight);
    }

    // function updateWhitelistedAddresses(address _user, bool _value) external onlyAdmin {
    //     whitelisted[_user] = _value;

    //     emit UpdatedWhitelist(_user, _value);
    // }

    // function updateWhitelistStatus(bool _value) external onlyAdmin {
    //     whitelistEnabled = _value;

    //     emit WhitelistStatusUpdated(_value);
    // }

    //--------------------------------------------------------------------------------------
    //------------------------------  INTERNAL FUNCTIONS  ----------------------------------
    //--------------------------------------------------------------------------------------

    function _allocateSourceOfFunds() public view returns (SourceOfFunds) {
        uint256 validatorRatio = (fundStatistics[SourceOfFunds.EETH].numberOfValidators * 10_000) / fundStatistics[SourceOfFunds.ETHER_FAN].numberOfValidators;
        uint256 weightRatio = (fundStatistics[SourceOfFunds.EETH].targetWeight * 10_000) / fundStatistics[SourceOfFunds.ETHER_FAN].targetWeight;

        if(validatorRatio > weightRatio) {
            return SourceOfFunds.ETHER_FAN;
        } else {
            return SourceOfFunds.EETH;
        }
    }

    function _checkHoldersUpdateStatus() internal {
        if(holdersUpdate.timestamp < uint32(_getCurrentSchedulingStartTimestamp())) {
            holdersUpdate.startOfSlotNumOwners = uint32(bnftHolders.length);
        }
        holdersUpdate.timestamp = uint32(block.timestamp);
    }

    function _getCurrentSchedulingStartTimestamp() internal view returns (uint256) {
        return block.timestamp - (block.timestamp % schedulingPeriodInSeconds);
    }

    function getArrayLength() public returns (uint256) {
        return bnftHolders.length;
    }

    function _isAssigned(uint256 _firstIndex, uint128 _lastIndex, uint256 _index) public view {
        if(_lastIndex < _firstIndex) {
            require(_index <= _lastIndex || (_index >= _firstIndex && _index < numberOfActiveSlots()), "Not assigned");
        }else {
            require(_index >= _firstIndex && _index <= _lastIndex, "Not assigned");
        }
    }

    function _getSlotIndex() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp / schedulingPeriodInSeconds))) % numberOfActiveSlots();
    }

    function _fetchLastIndex(uint128 _size, uint256 _index) internal view returns (uint128 lastIndex){
        uint32 numSlots = numberOfActiveSlots();
        uint128 tempLastIndex = uint128(_index) + _size - 1;
        lastIndex = (tempLastIndex + uint128(numSlots)) % uint128(numSlots);
    }

    function _isWhitelistedAndEligible(address _user, bytes32[] calldata _merkleProof) internal view {
        require(!whitelistEnabled || whitelisted[_user], "User is not whitelisted");
        require(regulationsManager.isEligible(regulationsManager.whitelistVersion(), _user) == true, "User is not eligible to participate");
    }

    function _sharesForDepositAmount(uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return _depositAmount;
        }
        return (_depositAmount * eETH.totalShares()) / totalPooledEther;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function getTotalEtherClaimOf(address _user) external view returns (uint256) {
        uint256 staked;
        uint256 totalShares = eETH.totalShares();
        if (totalShares > 0) {
            staked = (getTotalPooledEther() * eETH.shares(_user)) / totalShares;
        }
        return staked;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return totalValueOutOfLp + totalValueInLp;
    }

    function sharesForAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_amount * eETH.totalShares()) / totalPooledEther;
    }

    /// @dev withdrawal rounding errors favor the protocol by rounding up
    function sharesForWithdrawalAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
        if (totalPooledEther == 0) {
            return 0;
        }

        // ceiling division so rounding errors favor the protocol
        uint256 numerator = _amount * eETH.totalShares();
        return (numerator + totalPooledEther - 1) / totalPooledEther;
    }

    function amountForShare(uint256 _share) public view returns (uint256) {
        uint256 totalShares = eETH.totalShares();
        if (totalShares == 0) {
            return 0;
        }
        return (_share * getTotalPooledEther()) / totalShares;
    }

     function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _b : _a;
    }

    function getImplementation() external view returns (address) {return _getImplementation();}

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier whenLiquidStakingOpen() {
        require(eEthliquidStakingOpened, "Liquid staking functions are closed");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not the admin");
        _;
    }

    modifier onlyWithdrawRequestOrMembershipManager() {
        require(msg.sender == address(withdrawRequestNFT) || msg.sender == address(membershipManager), "Caller is not the WithdrawRequestNFT or MembershipManager");
        _;
    }

    modifier NonZeroAddress(address _address) {
        require(_address != address(0), "No zero addresses");
        _;
    }
}
