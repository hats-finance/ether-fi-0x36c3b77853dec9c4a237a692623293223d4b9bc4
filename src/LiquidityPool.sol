// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IScoreManager.sol";
import "../src/interfaces/IEtherFiNodesManager.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./interfaces/IEETH.sol";
import "./interfaces/IScoreManager.sol";
import "./interfaces/IStakingManager.sol";
import "forge-std/console.sol";

contract LiquidityPool is Initializable, OwnableUpgradeable, UUPSUpgradeable, IERC721ReceiverUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IEETH eETH; 
    IScoreManager scoreManager;
    IStakingManager stakingManager;

    mapping(uint256 => bool) public validators;
    uint256 public accruedSlashingPenalties;
    uint256 public accruedEapRewards;

    uint64 public numValidators;

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

    receive() external payable {}

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

    function batchDepositWithBidIds(uint256 _numDeposits, uint256[] calldata _candidateBidIds) public onlyOwner returns (uint256[] memory) {
        uint256 amount = 32 ether * _numDeposits;
        require(address(this).balance >= amount, "Not enough balance");
        uint256[] memory newValidators = stakingManager.batchDepositWithBidIds{value: amount}(_candidateBidIds);

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

    function getTotalEtherClaimOf(address _user) external view returns (uint256) {
        uint256 staked;
        uint256 boosted;
        if (eETH.totalShares() > 0) {
            staked = (getTotalPooledEther() * eETH.shares(_user)) / eETH.totalShares();
        }
        if (_totalEapScores() > 0) {
            boosted = (accruedEapRewards * _eapScore(_user)) / _totalEapScores();
        }
        return staked + boosted;
    }

    function getTotalPooledEther() public view returns (uint256) {
        return (32 ether * numValidators) + address(this).balance - (accruedSlashingPenalties + accruedEapRewards);
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

    function setScoreManager(address _address) external onlyOwner {
        scoreManager = IScoreManager(_address);
    }

    function setStakingManager(address _address) external onlyOwner {
        stakingManager = IStakingManager(_address);
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

    function _totalEapScores() internal view returns (uint256) {
        uint256 typeId = scoreManager.typeIds("Early Adopter Pool");
        bytes32 totalScore32 = scoreManager.totalScores(typeId);
        uint256 totalScore = abi.decode(bytes.concat(totalScore32), (uint256));
        return totalScore;
    }

    function _eapScore(address _user) internal view returns (uint256) {
        uint256 typeId = scoreManager.typeIds("Early Adopter Pool");
        bytes32 score32 = scoreManager.scores(typeId, _user);
        uint256 score = abi.decode(bytes.concat(score32), (uint256));
        return score;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

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
