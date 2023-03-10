// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/security/Pausable.sol";

import "./interfaces/IProtocolRevenueManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";

contract ProtocolRevenueManager is IProtocolRevenueManager, Pausable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
   
    address public owner;
    
    IEtherFiNodesManager etherFiNodesManager;
  
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

    // All of the received Ether is shared to all validators! Cool!
    receive() external payable {
        require(etherFiNodesManager.getNumberOfValidators() > 0, "No Active Validator");
        globalRevenueIndex += msg.value / etherFiNodesManager.getNumberOfValidators();
    }

    function addRevenue(uint256 _validatorId, uint256 _amount) external payable {
        require(msg.value == _amount, "Incorrect amount");
        require(etherFiNodesManager.getNumberOfValidators() > 0, "No Active Validator");
        etherFiNodesManager.setEtherFiNodeLocalRevenueIndex(_validatorId, globalRevenueIndex);
        globalRevenueIndex += msg.value / etherFiNodesManager.getNumberOfValidators();
    }
  
    /// @notice Distribute the accrued rewards to the validator
    /// @param _validatorId id of the validator
    function distributeRewards(uint256 _validatorId) external returns (uint256) {
        address etherFiNode = etherFiNodesManager.getEtherFiNodeAddress(_validatorId);
        uint256 amount = getAccruedRewards(_validatorId);
        IEtherFiNode(etherFiNode).receiveProtocolRevenue{value: amount}(amount, globalRevenueIndex);
        return amount;
    }

    function setEtherFiNodesManagerAddress(address _etherFiNodesManager) external onlyOwner {
        etherFiNodesManager = IEtherFiNodesManager(_etherFiNodesManager);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------


    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------


    /// @notice Compute the accrued rewards for a validator
    /// @param _validatorId id of the validator
    function getAccruedRewards(uint256 _validatorId) public view returns (uint256) {        
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
}
