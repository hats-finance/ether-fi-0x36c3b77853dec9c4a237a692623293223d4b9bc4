// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {

    struct DepositData {
        bytes publicKey;
        bytes signature; 
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }

    function stakeAmount() external view returns(uint128);
    function bidIdToStaker(uint256 id) external view returns (address);

    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds) external payable returns (uint256[] memory);
    function cancelDeposit(uint256 _validatorId) external;
    function registerValidator(uint256 _validatorId, DepositData calldata _depositData) external;
    function registerValidator(uint256 _validatorId, address _bNftRecipient, address _tNftRecipient, DepositData calldata _depositData) external;
    function batchRegisterValidators(uint256[] calldata _validatorId, DepositData[] calldata _depositData) external;
    function batchRegisterValidators(uint256[] calldata _validatorId, address[] calldata _bNftRecipients, address[] calldata _tNftRecipients, DepositData[] calldata _depositData) external;

    function fetchEtherFromContract(address _wallet) external; // TODO: Delete this in Mainnet
    
    function setEtherFiNodesManagerAddress(address _managerAddress) external;
}
