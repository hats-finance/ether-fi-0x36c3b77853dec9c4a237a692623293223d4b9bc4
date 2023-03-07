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
    uint256 localRevenueIndex;
    IStakingManager.DepositData depositData;
    uint64 exitRequestTimestamp;
    VALIDATOR_PHASE phase;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

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
        return depositData;
    }

    function getPhase() external view returns (VALIDATOR_PHASE) {
        return phase;
    }

    /// @notice Set the validator phase
    /// @param _phase the new phase
    function setPhase(VALIDATOR_PHASE _phase) external onlyOwner {
        phase = _phase;
    }

    /// @notice Set the deposit data
    /// @param _depositData the deposit data
    function setDepositData(IStakingManager.DepositData calldata _depositData) external onlyOwner {
        depositData = _depositData;
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
