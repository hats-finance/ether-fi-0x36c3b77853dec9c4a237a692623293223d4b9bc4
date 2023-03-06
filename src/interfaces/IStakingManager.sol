// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {
    //The phases of the staking process
    enum STAKE_PHASE {
        DEPOSITED,
        VALIDATOR_REGISTERED,
        INACTIVE
    }

    //The state of the validator
    enum VALIDATOR_PHASE {
        STAKE_DEPOSITED,
        REGISTERED,
        LIVE,
        EXITED
    }

    /// @notice Structure to hold the information on new Stakes
    /// @param staker - the address of the user who staked
    /// @param withdrawCredentials - withdraw credentials of the validator
    /// @param amount - amount of the stake
    /// @param phase - the current step of the stake
    

    /// @notice Structure to hold the information on validators
    /// @param bidId - id of the object holding the operators info.
    /// @param stakeId - id of the object holding the stakers info.
    /// @param validatorKey - encrypted validator key for use by the operator and staker
    struct Validator {
        uint128 validatorId;
        uint32 selectedBidId;
        uint32 stakeId;
        address staker;
        address withdrawSafe;
        VALIDATOR_PHASE phase;
        DepositData deposit_data;
    }

    struct DepositData {
        address operator;
        bytes withdrawalCredentials;
        bytes32 depositDataRoot;
        bytes publicKey;
        bytes signature;
    }

    function deposit() external payable;

    function cancelStake(uint256 _stakeId) external;

    function registerValidator(
        uint256 _stakeId,
        DepositData calldata _depositData
    ) external;

    function fetchEtherFromContract(address _wallet) external;

    function getStakerRelatedToValidator(uint256 _validatorId)
        external
        returns (address);

    function getStakeAmount() external returns (uint256);

    function setEtherFiNodesManagerAddress(address _managerAddress) external;
}
