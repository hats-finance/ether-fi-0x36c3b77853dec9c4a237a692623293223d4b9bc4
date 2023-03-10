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
    // TODO: immutable constants
    address etherfiNodesManager; // EtherFiNodesManager
    address protocolRevenueManagerAddress;

    uint256 localRevenueIndex;
    string ipfsHashForEncryptedValidatorKey;
    uint64 exitRequestTimestamp;
    VALIDATOR_PHASE phase;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    function initialize() public {
        require(etherfiNodesManager == address(0), "already initialised");
        etherfiNodesManager = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {
        // emit Received(msg.sender, msg.value);
    }

    function getIpfsHashForEncryptedValidatorKey() external view returns (string memory) {
        return ipfsHashForEncryptedValidatorKey;
    }

    function getPhase() external view returns (VALIDATOR_PHASE) {
        return phase;
    }

    function getLocalRevenueIndex() external view returns (uint256) {
        return localRevenueIndex;
    }


    /// @notice Set the validator phase
    /// @param _phase the new phase
    function setPhase(VALIDATOR_PHASE _phase) external onlyOwner {
        phase = _phase;
    }

    /// @notice Set the deposit data
    /// @param _ipfsHash the deposit data
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfsHash) external onlyOwner {
        ipfsHashForEncryptedValidatorKey = _ipfsHash;
    }

    function setLocalRevenueIndex(uint256 _localRevenueIndex) external onlyOwner {
        localRevenueIndex = _localRevenueIndex;
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

    function receiveProtocolRevenue(uint256 _amount, uint256 _globalRevenueIndex) payable external onlyProtocolRevenueManagerContract {
        require(msg.value == _amount, "Incorrect amount");
        localRevenueIndex = _globalRevenueIndex;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(
            msg.sender == etherfiNodesManager,
            "Only owner"
        );
        _;
    }

    // TODO
    modifier onlyProtocolRevenueManagerContract() {
        // require(
        //     msg.sender == protocolRevenueContract,
        //     "Only protocol revenue manager contract function"
        // );
        _;
    }
}
