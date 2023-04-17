// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IStakingManager {
    struct DepositData {
        bytes publicKey;
        bytes signature;
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }

    function bidIdToStaker(uint256 id) external view returns (address);

    function initialize(address _auctionAddress) external;
    function setEtherFiNodesManagerAddress(address _managerAddress) external;
    function setLiquidityPoolAddress(address _liquidityPoolAddress) external;
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds) external payable returns (uint256[] memory);

    function cancelDeposit(uint256 _validatorId) external;

    function registerValidator(bytes32 _depositRoot, uint256 _validatorId, DepositData calldata _depositData) external;
        
    function registerValidator(bytes32 _depositRoot, uint256 _validatorId, address _bNftRecipient, address _tNftRecipient, DepositData calldata _depositData) external;

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, DepositData[] calldata _depositData) external;

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, address _bNftRecipient, address _tNftRecipient, DepositData[] calldata _depositData) external;
}
