// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IProtocolRevenueManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IAuctionManager.sol";
import "lib/forge-std/src/console.sol";

contract ProtocolRevenueManager is IProtocolRevenueManager, Pausable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public owner;

    IEtherFiNodesManager etherFiNodesManager;
    IAuctionManager auctionManager;

    uint256 public globalRevenueIndex = 1;

    uint256 public constant vestedAuctionFeeSplitForStakers = 50; // 50% of the auction fee is vested for the {T, B}-NFT holders for 6 months
    uint256 public constant auctionFeeVestingPeriodForStakersInDays = 6 * 7 * 4;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    constructor() {
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    /// @notice All of the received Ether is shared to all validators! Cool!
    receive() external payable {
        require(
            etherFiNodesManager.getNumberOfValidators() > 0,
            "No Active Validator"
        );
        globalRevenueIndex +=
            msg.value /
            etherFiNodesManager.getNumberOfValidators();
    }

    /// @notice add the revenue from the auction fee paid by the node operator for the corresponding validator
    /// @param _validatorId the validator ID
    function addAuctionRevenue(
        uint256 _validatorId
    ) external payable onlyAuctionManager {
        require(
            etherFiNodesManager.getNumberOfValidators() > 0,
            "No Active Validator"
        );
        require(
            etherFiNodesManager.getEtherFiNodeLocalRevenueIndex(_validatorId) ==
                0,
            "auctionFeeTransfer is already processed for the validator."
        );

        address etherfiNode = etherFiNodesManager.getEtherFiNodeAddress(
            _validatorId
        );
        require(etherfiNode != address(0), "The validator Id is invalid.");

        IEtherFiNode(etherfiNode).setLocalRevenueIndex(globalRevenueIndex);
        uint256 amount = msg.value;
        uint256 vestingAmountForStakers = (vestedAuctionFeeSplitForStakers *
            amount) / 100;
        uint256 amountToProtocol = amount - vestingAmountForStakers;

        IEtherFiNode(etherfiNode).receiveVestedRewardsForStakers{
            value: vestingAmountForStakers
        }();
        globalRevenueIndex +=
            amountToProtocol /
            etherFiNodesManager.getNumberOfValidators();
    }

    // TODO auctionRevenueSplits = {NodeOperator: 50, Treasury: 25, Staker: 25}
    /// @notice Distribute the accrued rewards to the validator
    /// @param _validatorId id of the validator
    function distributeAuctionRevenue(
        uint256 _validatorId
    ) external onlyEtherFiNodesManager returns (uint256) {
        address etherFiNode = etherFiNodesManager.getEtherFiNodeAddress(
            _validatorId
        );
        uint256 amount = getAccruedAuctionRevenueRewards(_validatorId);
        IEtherFiNode(etherFiNode).receiveProtocolRevenue{value: amount}(
            globalRevenueIndex
        );
        return amount;
    }

    function setEtherFiNodesManagerAddress(
        address _etherFiNodesManager
    ) external onlyOwner {
        etherFiNodesManager = IEtherFiNodesManager(_etherFiNodesManager);
    }

    function setAuctionManagerAddress(
        address _auctionManager
    ) external onlyOwner {
        auctionManager = IAuctionManager(_auctionManager);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Compute the accrued rewards for a validator
    /// @param _validatorId id of the validator
    function getAccruedAuctionRevenueRewards(
        uint256 _validatorId
    ) public view returns (uint256) {
        address etherFiNode = etherFiNodesManager.getEtherFiNodeAddress(
            _validatorId
        );
        uint256 localRevenueIndex = IEtherFiNode(etherFiNode)
            .localRevenueIndex();
        uint256 amount = 0;
        if (localRevenueIndex > 0) {
            amount = globalRevenueIndex - localRevenueIndex;
        }
        return amount;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }

    modifier onlyEtherFiNodesManager() {
        require(
            msg.sender == address(etherFiNodesManager),
            "Only etherFiNodesManager function"
        );
        _;
    }

    modifier onlyAuctionManager() {
        require(
            msg.sender == address(auctionManager),
            "Only auction manager function"
        );
        _;
    }
}
