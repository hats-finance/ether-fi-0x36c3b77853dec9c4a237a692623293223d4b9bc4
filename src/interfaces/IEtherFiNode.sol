// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiNodesManager.sol";

interface IEtherFiNode {
    // State Transition Diagram for StateMachine contract:
    //
    //      NOT_INITIALIZED
    //              |
    //              ↓
    //      STAKE_DEPOSITED
    //           /      \
    //          /        \
    //         ↓          ↓
    //         LIVE    CANCELLED
    //         |  \ \ 
    //         |   \ \
    //         |   ↓  --> EVICTED
    //         |  BEING_SLASHED
    //         |    /
    //         |   /
    //         ↓  ↓
    //         EXITED
    //           |
    //           ↓
    //      FULLY_WITHDRAWN
    // Transitions are only allowed as directed above.
    // For instance, a transition from STAKE_DEPOSITED to either LIVE or CANCELLED is allowed,
    // but a transition from STAKE_DEPOSITED to NOT_INITIALIZED, BEING_SLASHED, or EXITED is not.
    //
    // All phase transitions should be made through the setPhase function,
    // which validates transitions based on these rules.
    enum VALIDATOR_PHASE {
        NOT_INITIALIZED,
        STAKE_DEPOSITED,
        WAITING_FOR_APPROVAL,
        LIVE,
        EXITED,
        FULLY_WITHDRAWN,
        CANCELLED,
        BEING_SLASHED,
        EVICTED
    }

    // VIEW functions
    function phase() external view returns (VALIDATOR_PHASE);

    function ipfsHashForEncryptedValidatorKey()
        external
        view
        returns (string memory);

    function stakingStartTimestamp() external view returns (uint32);

    function exitRequestTimestamp() external view returns (uint32);

    function exitTimestamp() external view returns (uint32);

    function getStakingRewardsPayouts(
        uint256 _beaconBalance,
        IEtherFiNodesManager.RewardsSplit memory _splits,
        uint256 _scale
    ) external view returns (uint256, uint256, uint256, uint256);

    function getNonExitPenalty(
        uint32 _tNftExitRequestTimestamp, 
        uint32 _bNftExitRequestTimestamp
    ) external view returns (uint256);

    function calculateTVL(
        uint256 _beaconBalance,
        IEtherFiNodesManager.RewardsSplit memory _SRsplits,
        uint256 _scale
    ) external view returns (uint256, uint256, uint256, uint256);

    // Non-VIEW functions
    function setPhase(VALIDATOR_PHASE _phase) external;

    function setIpfsHashForEncryptedValidatorKey(
        string calldata _ipfs
    ) external;

    function setExitRequestTimestamp() external;

    function markExited(uint32 _exitTimestamp) external;

    function markEvicted() external;

    // Withdraw Rewards
    function moveRewardsToManager(uint256 _amount) external;

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
}
