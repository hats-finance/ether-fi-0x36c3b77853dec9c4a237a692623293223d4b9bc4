// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {

    struct DepositData {
        bytes publicKey;
        bytes signature; 
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }

    function initialize(address _auctionAddress, address _tnftAddress, address _bnftAddress) external;

    function stakeAmount() external view returns(uint128);
    function bidIdToStaker(uint256 id) external view returns (address);

    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds) external payable returns (uint256[] memory);
    function cancelDeposit(uint256 _validatorId) external;
    function registerValidator(uint256 _validatorId, DepositData calldata _depositData) external;
    function fetchEtherFromContract(address _wallet) external;
    
    function setEtherFiNodesManagerAddress(address _managerAddress) external;
}
