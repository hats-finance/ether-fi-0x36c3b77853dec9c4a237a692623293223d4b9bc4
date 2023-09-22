// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/INodeOperatorManager.sol";
import "./interfaces/ILiquidityPool.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./EtherFiNode.sol";
import "./LiquidityPool.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin-upgradeable/contracts/proxy/beacon/IBeaconUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./libraries/DepositRootGenerator.sol";

import "forge-std/console2.sol";

contract StakingManager is
    Initializable,
    IStakingManager,
    IBeaconUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    
    uint128 public maxBatchDepositSize;
    uint128 public stakeAmount;

    address public implementationContract;
    address public liquidityPoolContract;

    bool public DEPRECATED_whitelistEnabled;
    bytes32 public merkleRoot;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionManager;
    IDepositContract public depositContractEth2;
    IEtherFiNodesManager public nodesManager;
    UpgradeableBeacon private upgradableBeacon;

    mapping(uint256 => address) public bidIdToStaker;

    address public DEPRECATED_admin;
    address public nodeOperatorManager;
    mapping(address => bool) public admins;
    mapping(uint256 => ILiquidityPool.SourceOfFunds) public validatorSourceOfFunds;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event StakeDeposit(address indexed staker, uint256 bidId, address withdrawSafe);
    event DepositCancelled(uint256 id);
    event ValidatorRegistered(address indexed operator, address indexed bNftOwner, address indexed tNftOwner, 
                              uint256 validatorId, bytes validatorPubKey, string ipfsHashForEncryptedValidatorKey);
    event StakeSource(uint256 bidId, ILiquidityPool.SourceOfFunds source);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev AuctionManager Contract must be deployed first
    /// @param _auctionAddress The address of the auction contract for interaction
    function initialize(address _auctionAddress) external initializer {
        require(_auctionAddress != address(0), "No zero addresses");

        stakeAmount = 32 ether;
        maxBatchDepositSize = 25;

        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        auctionManager = IAuctionManager(_auctionAddress);
        depositContractEth2 = IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b);
    }

    /// @notice Allows depositing multiple stakes at once
    /// @param _candidateBidIds IDs of the bids to be matched with each stake
    /// @return Array of the bid IDs that were processed and assigned
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, bool _enableRestaking)
        external payable whenNotPaused correctStakeAmount nonReentrant returns (uint256[] memory)
    {
        return _depositWithBidIds(_candidateBidIds, msg.sender, ILiquidityPool.SourceOfFunds.DELEGATED_STAKING, _enableRestaking);
    }

    /// @notice Allows depositing multiple stakes at once
    /// @param _candidateBidIds IDs of the bids to be matched with each stake
    /// @return Array of the bid IDs that were processed and assigned
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, address _staker, ILiquidityPool.SourceOfFunds _source, bool _enableRestaking)
        public payable whenNotPaused nonReentrant correctStakeAmount returns (uint256[] memory)
    {
        require(msg.sender == liquidityPoolContract, "Incorrect Caller");
        return _depositWithBidIds(_candidateBidIds, _staker, _source, _enableRestaking);
    }

    /// @notice Batch creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _depositRoot The fetched root of the Beacon Chain
    /// @param _validatorId Array of IDs of the validator to register
    /// @param _depositData Array of data structures to hold all data needed for depositing to the beacon chain
    function batchRegisterValidators(
        bytes32 _depositRoot,
        uint256[] calldata _validatorId,
        DepositData[] calldata _depositData
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {
        require(_validatorId.length <= maxBatchDepositSize, "Too many validators");
        require(_validatorId.length == _depositData.length, "Array lengths must match");

        for (uint256 x; x < _validatorId.length; ++x) {
            _registerValidator(_validatorId[x], msg.sender, msg.sender, _depositData[x], msg.sender, 32 ether);
        }
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _depositRoot The fetched root of the Beacon Chain
    /// @param _validatorId Array of IDs of the validator to register
    /// @param _bNftRecipient Array of BNFT recipients
    /// @param _tNftRecipient Array of TNFT recipients
    /// @param _depositData Array of data structures to hold all data needed for depositing to the beacon chain
    function batchRegisterValidators(
        bytes32 _depositRoot,
        uint256[] calldata _validatorId,
        address _bNftRecipient,
        address _tNftRecipient,
        DepositData[] calldata _depositData,
        address _staker
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {
        require(msg.sender == liquidityPoolContract, "Only LiquidityPool can call this function");
        require(_validatorId.length <= maxBatchDepositSize, "Too many validators");
        require(_validatorId.length == _depositData.length, "Array lengths must match");

        for (uint256 x; x < _validatorId.length; ++x) {
            _registerValidator(_validatorId[x], _bNftRecipient, _tNftRecipient, _depositData[x], _staker, 1 ether);
        }
    }

    // TOOD - discuss if we need to receive the full `DepositData` for stronger verification
    function batchApproveRegistration(
        uint256[] memory _validatorId, 
        bytes[] calldata _pubKey,
        bytes[] calldata _signature,
        bytes32[] calldata _depositDataRootApproval
    ) external {
        require(msg.sender == liquidityPoolContract, "Only LiquidityPool can call this function");

        for (uint256 x; x < _validatorId.length; ++x) {
            nodesManager.setEtherFiNodePhase(_validatorId[x], IEtherFiNode.VALIDATOR_PHASE.LIVE);
            // Deposit to the Beacon Chain
            bytes memory withdrawalCredentials = nodesManager.getWithdrawalCredentials(_validatorId[x]);
            bytes32 beaconChainDepositRoot = depositRootGenerator.generateDepositRoot(_pubKey[x], _signature[x], withdrawalCredentials, 31 ether);
            bytes32 registeredDataRoot = _depositDataRootApproval[x];
            require(beaconChainDepositRoot == registeredDataRoot, "Incorrect deposit data root");
            depositContractEth2.deposit{value: 31 ether}(_pubKey[x], withdrawalCredentials, _signature[x], beaconChainDepositRoot);
        }
    }

    /// @notice Cancels a user's deposits
    /// @param _validatorIds the IDs of the validators deposits to cancel
    function batchCancelDeposit(uint256[] calldata _validatorIds) public whenNotPaused nonReentrant {
        for (uint256 x; x < _validatorIds.length; ++x) {
            _cancelDeposit(_validatorIds[x], msg.sender);
        }
    }

    /// @notice Cancels a user's deposits
    /// @param _validatorIds the IDs of the validators deposits to cancel
    function batchCancelDepositAsBnftHolder(uint256[] calldata _validatorIds, address _caller) public whenNotPaused nonReentrant {
        uint32 numberOfEethValidators;
        uint32 numberOfEtherFanValidators;
        for (uint256 x; x < _validatorIds.length; ++x) { 
            if(validatorSourceOfFunds[_validatorIds[x]] == ILiquidityPool.SourceOfFunds.EETH){
                numberOfEethValidators++;
            } else if (validatorSourceOfFunds[_validatorIds[x]] == ILiquidityPool.SourceOfFunds.ETHER_FAN) {
                numberOfEtherFanValidators++;
            }
            _cancelDeposit(_validatorIds[x], _caller);
        }

        ILiquidityPool(liquidityPoolContract).decreaseSourceOfFundsValidators(numberOfEethValidators, numberOfEtherFanValidators);
    }

    /// @notice Sets the EtherFi node manager contract
    /// @param _nodesManagerAddress address of the manager contract being set
    function setEtherFiNodesManagerAddress(address _nodesManagerAddress) public onlyOwner {
        require(address(nodesManager) == address(0), "Address already set");
        require(_nodesManagerAddress != address(0), "No zero addresses");

        nodesManager = IEtherFiNodesManager(_nodesManagerAddress);
    }

    /// @notice Sets the Liquidity pool contract address
    /// @param _liquidityPoolAddress address of the liquidity pool contract being set
    function setLiquidityPoolAddress(address _liquidityPoolAddress) public onlyOwner {
        require(liquidityPoolContract == address(0), "Address already set");
        require(_liquidityPoolAddress != address(0), "No zero addresses");

        liquidityPoolContract = _liquidityPoolAddress;
    }

    /// @notice Sets the max number of deposits allowed at a time
    /// @param _newMaxBatchDepositSize the max number of deposits allowed
    function setMaxBatchDepositSize(uint128 _newMaxBatchDepositSize) public onlyAdmin {
        maxBatchDepositSize = _newMaxBatchDepositSize;
    }

    function registerEtherFiNodeImplementationContract(address _etherFiNodeImplementationContract) public onlyOwner {
        require(implementationContract == address(0), "Address already set");
        require(_etherFiNodeImplementationContract != address(0), "No zero addresses");

        implementationContract = _etherFiNodeImplementationContract;
        upgradableBeacon = new UpgradeableBeacon(implementationContract);      
    }

    /// @notice Instantiates the TNFT interface
    /// @param _tnftAddress Address of the TNFT contract
    function registerTNFTContract(address _tnftAddress) public onlyOwner {
        require(address(TNFTInterfaceInstance) == address(0), "Address already set");
        require(_tnftAddress != address(0), "No zero addresses");

        TNFTInterfaceInstance = ITNFT(_tnftAddress);
    }

    /// @notice Instantiates the BNFT interface
    /// @param _bnftAddress Address of the BNFT contract
    function registerBNFTContract(address _bnftAddress) public onlyOwner {
        require(address(BNFTInterfaceInstance) == address(0), "Address already set");
        require(_bnftAddress != address(0), "No zero addresses");

        BNFTInterfaceInstance = IBNFT(_bnftAddress);
    }

    /// @notice Upgrades the etherfi node
    /// @param _newImplementation The new address of the etherfi node
    function upgradeEtherFiNode(address _newImplementation) public onlyOwner {
        require(_newImplementation != address(0), "No zero addresses");
        
        upgradableBeacon.upgradeTo(_newImplementation);
        implementationContract = _newImplementation;
    }

    function pauseContract() external onlyAdmin { _pause(); }
    function unPauseContract() external onlyAdmin { _unpause(); }

    /// @notice Updates the address of the admin
    /// @param _address the new address to set as admin
    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        admins[_address] = _isAdmin;
    }

    function registerEth2DepositContract(address _address) public onlyOwner {
        require(_address != address(0), "No zero addresses");
        depositContractEth2 = IDepositContract(_address);
    }

    function setNodeOperatorManager(address _nodeOperateManager) external onlyAdmin {
        require(_nodeOperateManager != address(0), "Cannot be address zero");
        nodeOperatorManager = _nodeOperateManager;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _depositWithBidIds(
        uint256[] calldata _candidateBidIds, 
        address _staker, 
        ILiquidityPool.SourceOfFunds _source,
        bool _enableRestaking
    ) internal returns (uint256[] memory){

        require(_candidateBidIds.length > 0, "No bid Ids provided");
        uint256 numberOfDeposits = msg.value / stakeAmount;
        require(numberOfDeposits <= maxBatchDepositSize, "Batch too large");
        require(auctionManager.numberOfActiveBids() >= numberOfDeposits, "No bids available at the moment");

        uint256[] memory processedBidIds = new uint256[](numberOfDeposits);
        uint256 processedBidIdsCount = 0;

        for (uint256 i = 0;
            i < _candidateBidIds.length && processedBidIdsCount < numberOfDeposits;
            ++i) {
            uint256 bidId = _candidateBidIds[i];
            address bidStaker = bidIdToStaker[bidId];
            address operator = auctionManager.getBidOwner(bidId);
            bool isActive = auctionManager.isBidActive(bidId);
            if (bidStaker == address(0) && isActive) {
                require(_verifyNodeOperator(operator, _source), "Operator not verified");
                auctionManager.updateSelectedBidInformation(bidId);
                validatorSourceOfFunds[bidId] = _source;
                processedBidIds[processedBidIdsCount] = bidId;
                processedBidIdsCount++;
                _processDeposit(bidId, _staker, _enableRestaking, _source);
            }
        }

        // resize the processedBidIds array to the actual number of processed bid IDs
        assembly {
            mstore(processedBidIds, processedBidIdsCount)
        }

        //Need to refund the BNFT holder, currently we just sending the 30 ETH from LP back
        uint256 unMatchedBidCount = numberOfDeposits - processedBidIdsCount;
        if (unMatchedBidCount > 0) {
            _refundDeposit(msg.sender, stakeAmount * unMatchedBidCount);
        }

        return processedBidIds;
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId ID of the validator to register
    /// @param _bNftRecipient The address to receive the minted B-NFT
    /// @param _tNftRecipient The address to receive the minted T-NFT
    /// @param _depositData Data structure to hold all data needed for depositing to the beacon chain
    /// @param _staker User who has begun the registration chain of transactions
    /// however, instead of the validator key, it will include the IPFS hash
    /// containing the validator key encrypted by the corresponding node operator's public key
    function _registerValidator(
        uint256 _validatorId, 
        address _bNftRecipient, 
        address _tNftRecipient, 
        DepositData calldata _depositData, 
        address _staker,
        uint256 _depositAmount
    ) internal {
        require(bidIdToStaker[_validatorId] == _staker, "Not deposit owner");
        bytes memory withdrawalCredentials = nodesManager.getWithdrawalCredentials(_validatorId);
        bytes32 depositDataRoot = depositRootGenerator.generateDepositRoot(_depositData.publicKey, _depositData.signature, withdrawalCredentials, _depositAmount);
        require(depositDataRoot == _depositData.depositDataRoot, "Deposit data root mismatch");

        if(_tNftRecipient == liquidityPoolContract) {
            nodesManager.setEtherFiNodePhase(_validatorId, IEtherFiNode.VALIDATOR_PHASE.WAITING_FOR_APPROVAL);
        } else {
            nodesManager.setEtherFiNodePhase(_validatorId, IEtherFiNode.VALIDATOR_PHASE.LIVE);
        }

        // Deposit to the Beacon Chain
        depositContractEth2.deposit{value: _depositAmount}(_depositData.publicKey, withdrawalCredentials, _depositData.signature, depositDataRoot);
        nodesManager.setEtherFiNodeIpfsHashForEncryptedValidatorKey(_validatorId, _depositData.ipfsHashForEncryptedValidatorKey);

        nodesManager.incrementNumberOfValidators(1);
        auctionManager.processAuctionFeeTransfer(_validatorId);
        
        // Let validatorId = nftTokenId
        uint256 nftTokenId = _validatorId;
        TNFTInterfaceInstance.mint(_tNftRecipient, nftTokenId);
        BNFTInterfaceInstance.mint(_bNftRecipient, nftTokenId);

        emit ValidatorRegistered(
            auctionManager.getBidOwner(_validatorId),
            _bNftRecipient,
            _tNftRecipient,
            _validatorId,
            _depositData.publicKey,
            _depositData.ipfsHashForEncryptedValidatorKey
        );
    }

    /// @notice Update the state of the contract now that a deposit has been made
    /// @param _bidId The bid that won the right to the deposit
    function _processDeposit(uint256 _bidId, address _staker, bool _enableRestaking, ILiquidityPool.SourceOfFunds _source) internal {
        bidIdToStaker[_bidId] = _staker;
        uint256 validatorId = _bidId;

        // register a withdrawalSafe for this bid/validator, creating a new one if necessary
        address etherfiNode = nodesManager.registerEtherFiNode(validatorId, _enableRestaking);
    /*
        if (_enableRestaking) {
            IEtherFiNode(etherfiNode).createEigenPod(); // NOOP if already has an associated eigenPod
        }
    */

        emit StakeDeposit(_staker, _bidId, etherfiNode);
        emit StakeSource(_bidId, _source);
    }

    /// @notice Cancels a users stake
    /// @param _validatorId the ID of the validator deposit to cancel
    function _cancelDeposit(uint256 _validatorId, address _caller) internal {

        require(bidIdToStaker[_validatorId] == _caller, "Not deposit owner");

        IEtherFiNode.VALIDATOR_PHASE validatorPhase = nodesManager.phase(_validatorId);
        console2.log("_cancelDeposit start phase", uint256(validatorPhase));

        bidIdToStaker[_validatorId] = address(0);
        nodesManager.setEtherFiNodePhase(_validatorId, IEtherFiNode.VALIDATOR_PHASE.CANCELLED);
        nodesManager.unregisterEtherFiNode(_validatorId);

        // Call function in auction contract to re-initiate the bid that won
        auctionManager.reEnterAuction(_validatorId);
        if(validatorPhase == IEtherFiNode.VALIDATOR_PHASE.WAITING_FOR_APPROVAL) {
            _refundDeposit(msg.sender, 31 ether);
        } else {
            _refundDeposit(msg.sender, stakeAmount);
        }

        //Might need to burn BNFT

        emit DepositCancelled(_validatorId);

        require(bidIdToStaker[_validatorId] == address(0), "Bid already cancelled");
    }

    /// @notice Refunds the depositor their staked ether for a specific stake
    /// @dev called internally from cancelStakingManager or when the time runs out for calling registerValidator
    /// @param _depositOwner address of the user being refunded
    /// @param _amount the amount to refund the depositor
    function _refundDeposit(address _depositOwner, uint256 _amount) internal {
        (bool sent, ) = _depositOwner.call{value: _amount}("");
        require(sent, "Failed to send Ether"); 
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _verifyNodeOperator(address _operator, ILiquidityPool.SourceOfFunds _source) internal returns (bool approved) {
        if(uint256(ILiquidityPool.SourceOfFunds.DELEGATED_STAKING) == uint256(_source)) {
            approved = true;
        } else {
            approved = INodeOperatorManager(nodeOperatorManager).isEligibleToRunValidatorsForSourceOfFund(_operator, _source);
        }
    }

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Fetches the address of the beacon contract for future EtherFiNodes (withdrawal safes)
    function getEtherFiNodeBeacon() external view returns (address) {
        return address(upgradableBeacon);
    }

    /// @notice Fetches the address of the implementation contract currently being used by the proxy
    /// @return the address of the currently used implementation contract
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    /// @notice Fetches the address of the implementation contract currently being used by the beacon proxy
    /// @return the address of the currently used implementation contract
    function implementation() public view override returns (address) {
        return upgradableBeacon.implementation();
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier correctStakeAmount() {
        require(msg.value > 0 && msg.value % stakeAmount == 0, "Insufficient staking amount");
        _;
    }

    modifier verifyDepositState(bytes32 _depositRoot) {
        // disable deposit root check if none provided
        if (_depositRoot != 0x0000000000000000000000000000000000000000000000000000000000000000) {
            bytes32 onchainDepositRoot = depositContractEth2.get_deposit_root();
            require(_depositRoot == onchainDepositRoot, "deposit root changed");
        }
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not the admin");
        _;
    }
}
