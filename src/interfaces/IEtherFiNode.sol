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
    function setDepositData(IStakingManager.DepositData calldata _deposit_data) external;

    function getPhase() external view returns (VALIDATOR_PHASE);
    function getDepositData() external view returns (IStakingManager.DepositData memory);

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
