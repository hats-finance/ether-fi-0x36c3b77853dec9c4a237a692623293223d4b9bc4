// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IDeposit {

    //The phases of the staking process
    enum STAKE_PHASE {
        DEPOSITED,
        VALIDATOR_REGISTERED,
        INACTIVE
    }

    //The state of the validator
    enum VALIDATOR_PHASE {
        HANDOVER_READY,
        ACCEPTED,
        LIVE,
        EXITED
    }

    /// @notice Structure to hold the information on new Stakes
    /// @param staker - the address of the user who staked
    /// @param withdrawCredentials - withdraw credentials of the validator
    /// @param amount - amount of the stake
    /// @param phase - the current step of the stake
    struct Stake {
        address staker;
        address withdrawSafe;
        DepositData deposit_data;
        uint256 amount;
        uint256 winningBid;
        uint256 stakeId;
        STAKE_PHASE phase;
    }

    /// @notice Structure to hold the information on validators
    /// @param bidId - id of the object holding the operators info.
    /// @param stakeId - id of the object holding the stakers info.
    /// @param validatorKey - encrypted validator key for use by the operator and staker
    struct Validator {
        uint256 validatorId;
        uint256 bidId;
        uint256 stakeId;
        bytes validatorKey;
        VALIDATOR_PHASE phase;
    }

    struct DepositData {
        address operator;
        bytes32 withdrawalCredentials;
        bytes32 depositDataRoot;
        bytes publicKey;
        bytes signature;
    }

    function deposit(DepositData calldata _deposit_data) external payable;

    function cancelStake(uint256 _stakeId) external;

    function registerValidator(uint256 _stakeId, bytes memory _validatorKey) external;

    function acceptValidator(uint256 _validatorId) external;

}
