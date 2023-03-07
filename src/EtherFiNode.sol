// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IStakingManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "lib/forge-std/src/console.sol";

contract EtherFiNode is IEtherFiNode {
    address owner;
    VALIDATOR_PHASE phase;
    IStakingManager.DepositData deposit_data;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------
    
    /// @notice Constructor to set variables on deployment
    constructor() {
    }

    function initialize() public {
        require(owner == address(0), "already initialised");
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {
        // emit Received(msg.sender, msg.value);
    }

    function getDepositData() external view returns (IStakingManager.DepositData memory) {
        return deposit_data;
    }

    function getPhase() external view returns (VALIDATOR_PHASE) {
        return phase;
    }

    function setPhase(VALIDATOR_PHASE _phase) external onlyOwner {
        phase = _phase;
    }

    function setDepositData(IStakingManager.DepositData calldata _deposit_data) external onlyOwner {
        deposit_data = _deposit_data;
    }

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external onlyOwner {
        (bool sent, ) = _treasury.call{value: _treasuryAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_operator).call{value: _operatorAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_tnftHolder).call{value: _tnftAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_bnftHolder).call{value: _bnftAmount}("");
        require(sent, "Failed to send Ether");
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner"
        );
        _;
    }
}
