// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./ILiquidityPool.sol";

interface IStakingManager {
    struct DepositData {
        bytes publicKey;
        bytes signature;
        bytes32 depositDataRoot;
        string ipfsHashForEncryptedValidatorKey;
    }

    function bidIdToStaker(uint256 id) external view returns (address);
    function verifyWhitelisted(address _address, bytes32[] calldata _merkleProof) external view;
    function merkleRoot() external view returns (bytes32);
    function whitelistEnabled() external view returns (bool);

    function initialize(address _auctionAddress) external;
    function setEtherFiNodesManagerAddress(address _managerAddress) external;
    function setLiquidityPoolAddress(address _liquidityPoolAddress) external;
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, bytes32[] calldata _merkleProof, address _staker, ILiquidityPool.SourceOfFunds source) external payable returns (uint256[] memory);
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds, bytes32[] calldata _merkleProof) external payable returns (uint256[] memory);

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, DepositData[] calldata _depositData) external;

    function batchRegisterValidators(bytes32 _depositRoot, uint256[] calldata _validatorId, address _bNftRecipient, address _tNftRecipient, DepositData[] calldata _depositData, address _user) external;

    function batchApproveRegistration(uint256[] memory _validatorId, bytes[] calldata _pubKey, bytes[] calldata _signature) external;

    function batchCancelDeposit(uint256[] calldata _validatorIds) external;

    function batchCancelDepositAsBnftHolder(uint256[] calldata _validatorIds, address _caller) external;

    function updateAdmin(address _address, bool _isAdmin) external;
}
