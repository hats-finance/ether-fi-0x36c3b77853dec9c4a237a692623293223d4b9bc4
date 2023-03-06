// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {

    //The state of the validator
    enum VALIDATOR_PHASE {
        STAKE_DEPOSITED,
        REGISTERED,
        LIVE,
        EXITED,
        CANCELLED
    }

    /// @notice Structure to hold the information on validators
    /// @param validatorId - id of the object holding the operators info.
    /// @param selectedBidId - id of the object holding the operators info.
    /// @param staker - address of the staker who deposited the 32 ETH.
    /// @param etherFiNode - address of the node handling all funds associated to the validator.
    /// @param phase - the VALIDATOR_PHASE the validator is currently in.
    /// @param deposit_data - the validators deposit_data
    struct Validator {
        uint128 validatorId;
        uint128 selectedBidId;
        address staker;
        address etherFiNode;
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

    function cancelDeposit(uint256 _stakeId) external;

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
