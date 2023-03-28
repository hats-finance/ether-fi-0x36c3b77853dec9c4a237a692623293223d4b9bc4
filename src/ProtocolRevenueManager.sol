// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IProtocolRevenueManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IAuctionManager.sol";

contract ProtocolRevenueManager is IProtocolRevenueManager, Pausable, Ownable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IEtherFiNodesManager etherFiNodesManager;
    IAuctionManager auctionManager;

    uint256 public globalRevenueIndex = 1;

    uint128 public constant vestedAuctionFeeSplitForStakers = 50; // 50% of the auction fee is vested for the {T, B}-NFT holders for 6 months
    uint128 public constant auctionFeeVestingPeriodForStakersInDays = 6 * 7 * 4; // 6 months

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    constructor() {
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
            etherFiNodesManager.numberOfValidators() > 0,
            "No Active Validator"
        );
        globalRevenueIndex +=
            msg.value /
            etherFiNodesManager.numberOfValidators();
    }

    /// @notice add the revenue from the auction fee paid by the node operator for the corresponding validator
    /// @param _validatorId the validator ID
    function addAuctionRevenue(
        uint256 _validatorId
    ) external payable onlyAuctionManager {
        require(
            etherFiNodesManager.numberOfValidators() > 0,
            "No Active Validator"
        );
        require(
            etherFiNodesManager.localRevenueIndex(_validatorId) == 0,
            "addAuctionRevenue is already processed for the validator."
        );

        etherFiNodesManager.setEtherFiNodeLocalRevenueIndex(_validatorId, globalRevenueIndex);
        uint256 amount = msg.value;
        uint256 amountVestedForStakers = (vestedAuctionFeeSplitForStakers * amount) / 100;
        uint256 amountToProtocol = amount - amountVestedForStakers;

        address etherfiNode = etherFiNodesManager.etherfiNodeAddress(_validatorId);
        IEtherFiNode(etherfiNode).receiveVestedRewardsForStakers{value: amountVestedForStakers}();
        globalRevenueIndex += amountToProtocol / etherFiNodesManager.numberOfValidators();
    }

    /// @notice Distribute the accrued rewards to the validator
    /// @param _validatorId id of the validator
    function distributeAuctionRevenue(
        uint256 _validatorId
    ) external onlyEtherFiNodesManager returns (uint256) {
        uint256 amount = getAccruedAuctionRevenueRewards(_validatorId);
        etherFiNodesManager.setEtherFiNodeLocalRevenueIndex{value: amount}(_validatorId, globalRevenueIndex);
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
        address etherFiNode = etherFiNodesManager.etherfiNodeAddress(_validatorId);
        uint256 localRevenueIndex = IEtherFiNode(etherFiNode).localRevenueIndex();
        uint256 amount = 0;
        if (localRevenueIndex > 0) {
            amount = globalRevenueIndex - localRevenueIndex;
        }
        return amount;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

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
