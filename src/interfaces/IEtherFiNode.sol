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
        LIVE,
        EXITED,
        FULLY_WITHDRAWN,
        CANCELLED,
        BEING_SLASHED,
        EVICTED,
        WAITING_FOR_APPROVAL
    }

    function initialize(address _etherFiNodesManager) external;
    function setPhase(VALIDATOR_PHASE _phase) external;
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfs) external;
    function setExitRequestTimestamp() external;
    function markExited(uint32 _exitTimestamp) external;
    function markEvicted() external;
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
    function getStakingRewardsPayouts(
        uint256 _beaconBalance,
        IEtherFiNodesManager.RewardsSplit memory _splits,
        uint256 _scale
    ) external view returns (uint256, uint256, uint256, uint256);
    function getNonExitPenalty(uint32 _tNftExitRequestTimestamp,  uint32 _bNftExitRequestTimestamp) external view returns (uint256);
    function totalBalanceInExecutionLayer() external view returns (
        uint256 _withdrawalSafe, 
        uint256 _eigenPod, 
        uint256 _delayedWithdrawalRouter
    );
    function calculateTVL(
        uint256 _beaconBalance,
        IEtherFiNodesManager.RewardsSplit memory _SRsplits,
        uint256 _scale
    ) external view returns (uint256, uint256, uint256, uint256);
    function calculatePayouts(
        uint256 _totalAmount,
        IEtherFiNodesManager.RewardsSplit memory _splits,
        uint256 _scale
    ) external pure returns (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury);
    function calculatePrincipals(uint256 _balance) external pure returns (uint256 , uint256);
    function getWithdrawableAmount() external view returns (uint256);
    function createEigenPod() external ;
    function isRestakingEnabled() external view returns (bool);
    function hasOutstandingEigenLayerWithdrawals() external view returns (bool);
    function queueRestakedWithdrawal() external;
    function claimQueuedWithdrawals(uint256 maxNumWithdrawals) external;
    function phase() external view returns (VALIDATOR_PHASE);
    function eigenPod() external view returns (address);
    function ipfsHashForEncryptedValidatorKey() external view returns (string memory);
    function stakingStartTimestamp() external view returns (uint32);
    function exitRequestTimestamp() external view returns (uint32);
    function exitTimestamp() external view returns (uint32);
}
