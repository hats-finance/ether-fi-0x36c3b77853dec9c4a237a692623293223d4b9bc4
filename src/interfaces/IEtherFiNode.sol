// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";

interface IEtherFiNode {
    //The state of the validator
    enum VALIDATOR_PHASE {
        STAKE_DEPOSITED,
        REGISTERED,
        LIVE,
        EXITED,
        CANCELLED
    }

    function setPhase(VALIDATOR_PHASE _phase) external;
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfs) external;
    function setLocalRevenueIndex(uint256 _localRevenueIndex) external;

    function getPhase() external view returns (VALIDATOR_PHASE);
    function getIpfsHashForEncryptedValidatorKey() external view returns (string memory);
    function getLocalRevenueIndex() external view returns (uint256);

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external;

    function receiveProtocolRevenue(uint256 _amount, uint256 _globalRevenueIndex) payable external;
}
