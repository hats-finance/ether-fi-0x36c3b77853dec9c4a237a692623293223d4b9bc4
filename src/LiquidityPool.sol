// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";

import "./interfaces/IStakingManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IeETH.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IRegulationsManager.sol";
import "./interfaces/ImeETH.sol";


contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IeETH public eETH; 
    IStakingManager public stakingManager;
    IEtherFiNodesManager public nodesManager;
    IRegulationsManager public regulationsManager;
    ImeETH public meETH;

    uint256 public numValidators;
    uint256 public accruedSlashingPenalties;    // total amounts of accrued slashing penalties on the principals
    uint256 public accruedEther;                // total amounts of accrued ethers rewards + exited principals
    bool public eEthliquidStakingOpened;

    uint256[21] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

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
        // Staking Manager can send ETH to LP without updating 'accruedEther'
        // It occurs when the ETH sent to via 'batchDepositWithBidIds' is returned
        if (msg.sender == address(stakingManager)) {
            return;
        }
    
        require(accruedEther >= msg.value, "Update the accrued ethers first");
        accruedEther -= msg.value;
    }

    function initialize(address _regulationsManager) external initializer {
        require(_regulationsManager != address(0), "No zero addresses");

        __Ownable_init();
        __UUPSUpgradeable_init();
        regulationsManager = IRegulationsManager(_regulationsManager);
        eEthliquidStakingOpened = false;
    }

    function deposit(address _user, bytes32[] calldata _merkleProof) public payable {
        deposit(_user, _user, _merkleProof);
    }

    /// @notice deposit into pool
    /// @dev mints the amount of eETH 1:1 with ETH sent
    function deposit(address _user, address _recipient, bytes32[] calldata _merkleProof) public payable whenLiquidStakingOpen {
        stakingManager.verifyWhitelisted(_user, _merkleProof);
        require(regulationsManager.isEligible(regulationsManager.whitelistVersion(), _user), "User is not whitelisted");
        require(_recipient == msg.sender || _recipient == address(meETH), "Wrong Recipient");

        uint256 share = _sharesForDepositAmount(msg.value);
        if (share == 0) {
            share = msg.value;
        }
        eETH.mintShares(_recipient, share);

        emit Deposit(_recipient, msg.value);
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to user
    /// @param _amount the amount to withdraw from contract
    function withdraw(address _recipient, uint256 _amount) public whenLiquidStakingOpen {
        require(address(this).balance >= _amount, "Not enough ETH in the liquidity pool");
        require(eETH.balanceOf(_recipient) >= _amount, "Not enough eETH");

        uint256 share = sharesForAmount(_amount);
        eETH.burnShares(_recipient, share);

        (bool sent, ) = _recipient.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        emit Withdraw(_recipient, _amount);
    }

    /*
     * During ether.fi's phase 1 roadmap,
     * ether.fi's multi-sig will perform as a B-NFT holder which generates the validator keys and initiates the launch of validators
     * - {batchDepositWithBidIds, batchRegisterValidators} are used to launch the validators
     *  - ether.fi multi-sig should bring 2 ETH which is combined with 30 ETH from the liquidity pool to launch a validator
     * - {processNodeExit, sendExitRequests} are used to perform operational tasks to manage the liquidity
    */

    /// @notice ether.fi multi-sig (Owner) brings 2 ETH which is combined with 30 ETH from the liquidity pool and deposits 32 ETH into StakingManager
    function batchDepositWithBidIds(
        uint256 _numDeposits, 
        uint256[] calldata _candidateBidIds, 
        bytes32[] calldata _merkleProof
        ) payable public onlyOwner returns (uint256[] memory) {
        require(msg.value == 2 ether * _numDeposits, "B-NFT holder must deposit 2 ETH per validator");
        require(address(this).balance >= 32 ether * _numDeposits, "Not enough balance");
        
        uint256 amount = 32 ether * _numDeposits;
        uint256[] memory newValidators = stakingManager.batchDepositWithBidIds{value: amount}(_candidateBidIds, _merkleProof);

        uint256 returnAmount = 2 ether * (_numDeposits - newValidators.length);
        (bool sent, ) = address(msg.sender).call{value: returnAmount}("");
        require(sent, "Failed to send Ether");

        return newValidators;
    }

    function batchRegisterValidators(
        bytes32 _depositRoot,
        uint256[] calldata _validatorIds,
        IStakingManager.DepositData[] calldata _depositData
        ) public onlyOwner
    {
        stakingManager.batchRegisterValidators(_depositRoot, _validatorIds, owner(), address(this), _depositData);
        numValidators += _validatorIds.length;
    }

    // After the nodes are exited, delist them from the liquidity pool
    function processNodeExit(uint256[] calldata _validatorIds, uint256[] calldata _slashingPenalties) public onlyOwner {
        uint256 totalSlashingPenalties = 0;
        uint256 totalPrincipals = 0;
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            require(nodesManager.phase(validatorId) == IEtherFiNode.VALIDATOR_PHASE.EXITED, "Incorrect Phase");
            (, uint256 toTnft, uint256 toBnft,) = nodesManager.getFullWithdrawalPayouts(validatorId);

            totalSlashingPenalties += _slashingPenalties[i];
            totalPrincipals += (toTnft >= 30 ether) ? 30 ether : toTnft;
        }

        numValidators -= _validatorIds.length;
        accruedEther += totalPrincipals;
        accruedSlashingPenalties -= totalSlashingPenalties;

        nodesManager.fullWithdrawBatch(_validatorIds);
    }

    /// @notice Send the exit reqeusts as the T-NFT holder
    function sendExitRequests(uint256[] calldata _validatorIds) public onlyOwner {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            nodesManager.sendExitRequest(validatorId);
        }
    }

    /// @notice Allow interactions with the eEth token
    function openEEthLiquidStaking() external onlyOwner {
        eEthliquidStakingOpened = true;
    }

    /// @notice Disallow interactions with the eEth token
    function closeEEthLiquidStaking() external onlyOwner {
        eEthliquidStakingOpened = false;
    }

    /// @notice ether.fi protocol will update the accrued staking rewards for rebasing
    function setAccruedEther(uint256 _amount) external onlyOwner {
        accruedEther = _amount;
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
        eETH = IeETH(_eETH);
    }

    function setStakingManager(address _address) external onlyOwner {
        require(_address != address(0), "No zero addresses");
        stakingManager = IStakingManager(_address);
    }

    function setEtherFiNodesManager(address _nodeManager) public onlyOwner {
        require(_nodeManager != address(0), "No zero addresses");
        nodesManager = IEtherFiNodesManager(_nodeManager);
    }

    function setMeETH(address _address) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        meETH = ImeETH(_address);
    }
    
    //--------------------------------------------------------------------------------------
    //------------------------------  INTERNAL FUNCTIONS  ----------------------------------
    //--------------------------------------------------------------------------------------

    function _sharesForDepositAmount(uint256 _depositAmount) internal view returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _depositAmount;
        if (totalPooledEther == 0) {
            return 0;
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
        return (30 ether * numValidators) + accruedEther + address(this).balance - (accruedSlashingPenalties);
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
        return (_share * getTotalPooledEther()) / totalShares;
    }

    function getImplementation() external view returns (address) {return _getImplementation();}

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier whenLiquidStakingOpen() {
        require(eEthliquidStakingOpened, "Liquid staking functions are closed");
        _;
    }
}
