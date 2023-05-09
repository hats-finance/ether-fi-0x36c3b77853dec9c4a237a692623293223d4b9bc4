// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNodesManager.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";
import "./interfaces/IEETH.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IRegulationsManager.sol";
import "./interfaces/IMEETH.sol";


contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IEETH public eETH; 
    IStakingManager public stakingManager;
    IEtherFiNodesManager public nodesManager;
    IRegulationsManager public regulationsManager;
    IMEETH public meEth;

    mapping(uint256 => bool) public validators;
    uint256 public accruedSlashingPenalties;    // total amounts of accrued slashing penalties on the principals
    uint256 public accruedStakingRewards;       // total amounts of accrued staking rewards beyond the principals

    uint64 public numValidators;

    bytes32[] private merkleProof;

    uint256[41] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Received(address indexed sender, uint256 value);
    event TokenAddressChanged(address indexed newAddress);
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {
        require(accruedStakingRewards >= msg.value, "Update the accrued rewards first");
        accruedStakingRewards -= msg.value;
    }

    function initialize(address _regulationsManager) external initializer {
        require(_regulationsManager != address(0), "No zero addresses");
        
        __Ownable_init();
        __UUPSUpgradeable_init();
        regulationsManager = IRegulationsManager(_regulationsManager);
    }

    function deposit(address _user, bytes32[] calldata _merkleProof) public payable {
        deposit(_user, _user, _merkleProof);
    }

    /// @notice deposit into pool
    /// @dev mints the amount of eETH 1:1 with ETH sent
    function deposit(address _user, address _recipient, bytes32[] calldata _merkleProof) public payable {
        stakingManager.verifyWhitelisted(_user, _merkleProof);
        require(regulationsManager.isEligible(regulationsManager.whitelistVersion(), _user), "User is not whitelisted");
        require(_recipient == msg.sender || isDepositToInternalContract(_recipient), "");

        uint256 share = _sharesForDepositAmount(msg.value);
        if (share == 0) {
            share = msg.value;
        }
        eETH.mintShares(_recipient, share);

        emit Deposit(_recipient, msg.value);
    }

    function withdraw(uint256 _amount) public payable {
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough eETH");
        withdraw(msg.sender, _amount);
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to user
    /// @param _amount the amount to withdraw from contract
    /// TODO WARNING! This implementation does not take into consideration the score
    function withdraw(address _recipient, uint256 _amount) public payable {
        require(address(this).balance >= _amount, "Not enough ETH in the liquidity pool");

        uint256 share = sharesForAmount(_amount);
        eETH.burnShares(_recipient, share);

        (bool sent, ) = _recipient.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        
        emit Withdraw(_recipient, msg.value);
    }

    function batchDepositWithBidIds(uint256 _numDeposits, uint256[] calldata _candidateBidIds) public onlyOwner returns (uint256[] memory) {
        uint256 amount = 32 ether * _numDeposits;
        require(address(this).balance >= amount, "Not enough balance");
        uint256[] memory newValidators = stakingManager.batchDepositWithBidIds{value: amount}(_candidateBidIds, merkleProof);

        return newValidators;
    }

    function batchRegisterValidators(
        bytes32 _depositRoot, 
        uint256[] calldata _validatorIds,
        IStakingManager.DepositData[] calldata _depositData
        ) public onlyOwner 
    {  
        stakingManager.batchRegisterValidators(_depositRoot, _validatorIds, owner(), address(this), _depositData);
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            validators[validatorId] = true;
        }
        numValidators += uint64(_validatorIds.length);
    }

    // After the nodes are exited, delist them from the liquidity pool
    function processNodeExit(uint256[] calldata _validatorIds, uint256[] calldata _slashingPenalties) public onlyOwner {
        uint256 totalSlashingPenalties = 0;
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            require(nodesManager.phase(validatorId) == IEtherFiNode.VALIDATOR_PHASE.EXITED, "Incorrect Phase");
            validators[validatorId] = false;
            totalSlashingPenalties += _slashingPenalties[i];
        }
        numValidators -= uint64(_validatorIds.length);
        accruedSlashingPenalties -= totalSlashingPenalties;
    }

    // Send the exit reqeusts as the T-NFT holder
    function sendExitRequests(uint256[] calldata _validatorIds) public onlyOwner {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            nodesManager.sendExitRequest(validatorId);
        }
    }

    function getTotalEtherClaimOf(address _user) external view returns (uint256) {
        uint256 staked;
        uint256 totalShares = eETH.totalShares();
        if (totalShares > 0) {
            staked = (getTotalPooledEther() * eETH.shares(_user)) / totalShares;
        }
        return staked;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return (32 ether * numValidators) + accruedStakingRewards + address(this).balance - (accruedSlashingPenalties);
    }

    function sharesForAmount(uint256 _amount) public view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther();
       
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_amount * eETH.totalShares()) / totalPooledEther;
    }

    function amountForShare(uint256 _share) public view returns (uint256) {
        uint256 totalShares = eETH.totalShares();
        if (totalShares == 0) {
            return 0;
        }
        return (_share * getTotalPooledEther()) / eETH.totalShares();
    }

    /// @notice ether.fi protocol will update the accrued staking rewards for rebasing
    function setAccruedStakingReards(uint256 _amount) external onlyOwner {
        accruedStakingRewards = _amount;
    }

    /// @notice ether.fi protocol will be monitoring the status of validator nodes
    ///         and update the accrued slashing penalties, if nay
    function setAccruedSlashingPenalty(uint256 _amount) external onlyOwner {
        accruedSlashingPenalties = _amount;
    }

    /// @notice sets the contract address for eETH
    /// @param _eETH address of eETH contract
    function setTokenAddress(address _eETH) external onlyOwner {
        require(_eETH != address(0), "No zero addresses");
        eETH = IEETH(_eETH);
        emit TokenAddressChanged(_eETH);
    }

    function setStakingManager(address _address) external onlyOwner {
        require(_address != address(0), "No zero addresses");
        stakingManager = IStakingManager(_address);
    }

    function setMerkleProof(bytes32[] calldata _merkleProof) public onlyOwner {
        merkleProof = _merkleProof;
    }

    function setEtherFiNodesManager(address _nodeManager) public onlyOwner {
        require(_nodeManager != address(0), "No zero addresses");
        nodesManager = IEtherFiNodesManager(_nodeManager);
    }

    function setMeEth(address _address) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        meEth = IMEETH(_address);
    }
    
    //--------------------------------------------------------------------------------------
    //------------------------------  INTERNAL FUNCTIONS  ----------------------------------
    //--------------------------------------------------------------------------------------

    function isDepositToInternalContract(address _address) internal view returns (bool) {
        bool verified = false;
        if (_address == address(meEth)) {
            verified = true;
        }
        return verified;
    }

    function _sharesForDepositAmount(uint256 _depositAmount) internal returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_depositAmount * eETH.totalShares()) / totalPooledEther;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------
}
