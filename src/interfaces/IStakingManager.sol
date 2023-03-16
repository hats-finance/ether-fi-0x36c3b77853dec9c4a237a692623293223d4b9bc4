// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {

    struct DepositData {
        bytes publicKey;
        bytes signature; 
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }
    
    function cancelDeposit(uint256 _validatorId) external;

    function registerValidator(
        uint256 _validatorId,
        DepositData calldata _depositData
    ) external;

    function fetchEtherFromContract(address _wallet) external;

    function bidIdToStaker(uint256 id) external view returns (address);

    function stakeAmount() external view returns(uint256);

    function setEtherFiNodesManagerAddress(address _managerAddress) external;

    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds)
       external
       payable
       returns (uint256[] memory);
    
    function setProtocolRevenueManager(address _protocolRevenueManager) external;
}
