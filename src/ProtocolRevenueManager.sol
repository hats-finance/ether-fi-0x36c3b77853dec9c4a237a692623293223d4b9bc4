// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "lib/forge-std/src/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IProtocolRevenueManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IAuctionManager.sol";


contract ProtocolRevenueManager is IProtocolRevenueManager, Pausable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
   
    address public owner;
    
    IEtherFiNodesManager etherFiNodesManager;
    IAuctionManager auctionManager;
  
    uint256 globalRevenueIndex = 1;

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
        require(etherFiNodesManager.getNumberOfValidators() > 0, "No Active Validator");
        globalRevenueIndex += msg.value / etherFiNodesManager.getNumberOfValidators();
    }

    /// @notice add the revenue from the auction fee paid by the node operator for the corresponding validator
    /// @param _validatorId the validator ID
    /// @param _amount the amount of the auction fee
    function addAuctionRevenue(uint256 _validatorId, uint256 _amount) external payable onlyAuctionManager {
        require(msg.value == _amount, "Incorrect amount");
        require(etherFiNodesManager.getNumberOfValidators() > 0, "No Active Validator");
        require(etherFiNodesManager.getEtherFiNodeLocalRevenueIndex(_validatorId) == 0, "auctionFeeTransfer is already processed for the validator.");
        etherFiNodesManager.setEtherFiNodeLocalRevenueIndex(_validatorId, globalRevenueIndex);
        globalRevenueIndex += msg.value / etherFiNodesManager.getNumberOfValidators();
    }
  
    // TODO auctionRevenueSplits = {NodeOperator: 50, Treasury: 25, Staker: 25}
    /// @notice Distribute the accrued rewards to the validator
    /// @param _validatorId id of the validator
    function distributeAuctionRevenue(uint256 _validatorId) external returns (uint256) {
        address etherFiNode = etherFiNodesManager.getEtherFiNodeAddress(_validatorId);
        uint256 amount = getAccruedAuctionRevenueRewards(_validatorId);
        IEtherFiNode(etherFiNode).receiveProtocolRevenue{value: amount}(amount, globalRevenueIndex);
        return amount;
    }

    function setEtherFiNodesManagerAddress(address _etherFiNodesManager) external onlyOwner {
        etherFiNodesManager = IEtherFiNodesManager(_etherFiNodesManager);
    }

    function setAuctionManagerAddress(address _auctionManager) external onlyOwner {
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
    function getAccruedAuctionRevenueRewards(uint256 _validatorId) public view returns (uint256) {        
        address etherFiNode = etherFiNodesManager.getEtherFiNodeAddress(_validatorId);
        uint256 localRevenueIndex = IEtherFiNode(etherFiNode).getLocalRevenueIndex();
        uint256 amount = 0;
        if (localRevenueIndex > 0) {
            amount = globalRevenueIndex - localRevenueIndex;
        }
        return amount;
    }

    function getGlobalRevenueIndex() public view returns (uint256) {
        return globalRevenueIndex;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }

    modifier onlyAuctionManager() {
        require(msg.sender == address(auctionManager), "Only auction manager function");
        _;
    }

}

