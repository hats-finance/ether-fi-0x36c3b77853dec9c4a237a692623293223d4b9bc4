// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IDeposit {

    enum STAKE_PHASE {
        STEP_1,
        STEP_2,
        STEP_3
    }

    struct Stake {
        address staker,
        bytes32 withdrawCredentials,
        uint256 amount,
        STAKE_PHASE phase
    }

    struct Validator {
        bytes publicKey,
        bytes signature,
        bytes32 depositDataRoot,
        bytes32 StakeId
    }

    function deposit() external payable;

    function setStakeAmount(uint256 _newStakeAmount) external;
}
