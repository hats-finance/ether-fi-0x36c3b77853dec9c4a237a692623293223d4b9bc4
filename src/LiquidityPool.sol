// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./interfaces/IEETH.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IScoreManager.sol";
import "forge-std/console.sol";

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    // TODO replace the below with the storage in ScoreManager
    mapping(address => uint256) scores; // ScoreManager.scores
    uint256 totalScores; // ScoreManager.totalScores

    IEETH eETH; 
    IStakingManager stakingManager; 
    IEtherFiNodesManager nodesManager; 
    IScoreManager scoreManager;

    mapping(uint256 => bool) validators;
    uint256 accruedSlashingPenalties;
    uint256 accruedEapRewards;
    uint256 bufferedEth;

    uint64  numValidators;

    uint256[32] __gap;

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

    function initialize() external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice deposit into pool
    /// @dev mints the amount of eTH 1:1 with ETH sent
    function deposit(address _user) external payable {
        uint256 share = _sharesForAmountAfterDeposit(msg.value);
        if (share == 0) {
            share = msg.value;
        }
        eETH.mintShares(_user, share);

        emit Deposit(_user, msg.value);
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to user
    /// @param _amount the amount to withdraw from contract
    /// TODO WARNING! This implementation does not take into consideration the score
    function withdraw(uint256 _amount) external payable {
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough eETH");

        uint256 share = sharesForAmount(_amount);
        eETH.burnShares(msg.sender, share);

        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(msg.sender, msg.value);
    }

    function getTotalEtherClaimOf(address _user) external view returns (uint256) {
        uint256 staked;
        uint256 boosted;
        if (eETH.totalShares() > 0) {
            staked = (getTotalPooledEther() * eETH.shares(_user)) / eETH.totalShares();
        }
        if (totalScores > 0) {
            boosted = (accruedEapRewards * scores[_user]) / totalScores;
        }
        return staked + boosted;
    }

    function getEtherStakingPrincipal() public view returns (uint256) {
        return (32 ether * numValidators) - accruedSlashingPenalties;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return getEtherStakingPrincipal() + address(this).balance - accruedEapRewards;
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

    /// @notice ether.fi protocol will send the ETH as the rewards for EAP users
    function accrueEapRewards() external payable onlyOwner {
        accruedEapRewards += msg.value;
    }

    /// @notice ether.fi protocol will be monitoring the status of validator nodes
    ///         and update the accrued slashing penalties, if nay
    function setAccruedSlashingPenalty(uint256 _amount) external onlyOwner {
        accruedSlashingPenalties = _amount;
    }

    /// @notice sets the contract address for eETH
    /// @param _eETH address of eETH contract
    function setTokenAddress(address _eETH) external onlyOwner {
        eETH = IEETH(_eETH);
        emit TokenAddressChanged(_eETH);
    }

    //--------------------------------------------------------------------------------------
    //------------------------------  INTERNAL FUNCTIONS  ----------------------------------
    //--------------------------------------------------------------------------------------

    function _sharesForAmountAfterDeposit(uint256 _amount) internal returns (uint256) {
        uint256 totalPooledEther = getTotalPooledEther() - _amount;
        if (totalPooledEther == 0) {
            return 0;
        }
        return (_amount * eETH.totalShares()) / totalPooledEther;
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
