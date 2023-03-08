// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {

    struct DepositData {
        address operator;
        bytes withdrawalCredentials;
        bytes32 depositDataRoot;
        bytes publicKey;
        bytes signature;
    }

    function deposit(uint256 _bidId) external payable;

    function cancelDeposit(uint256 _validatorId) external;

    function registerValidator(
        uint256 _validatorId,
        DepositData calldata _depositData
    ) external;

    function fetchEtherFromContract(address _wallet) external;

    function getStakerRelatedToValidator(uint256 _validatorId)
        external
        returns (address);

    function getStakeAmount() external returns (uint256);

    function setEtherFiNodesManagerAddress(address _managerAddress) external;
}
