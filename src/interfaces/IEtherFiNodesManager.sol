// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IEtherFiNode.sol";
import "./IStakingManager.sol";

interface IEtherFiNodesManager {
    enum ValidatorRecipientType {
        TNFTHOLDER,
        BNFTHOLDER,
        TREASURY,
        OPERATOR
    }

    struct RewardsSplit {
        uint64 treasury;
        uint64 nodeOperator;
        uint64 tnft;
        uint64 bnft;
    }

    // VIEW functions
    function getNumberOfValidators() external view returns (uint256);

    function generateWithdrawalCredentials(address _address) external view returns (bytes memory);
    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory);

    function getEtherFiNodeAddress(uint256 _validatorId) external view returns (address);
    function getEtherFiNodePhase(uint256 _validatorId) external view returns (IEtherFiNode.VALIDATOR_PHASE phase);
    function getEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId) external view returns (string memory);
    function getEtherFiNodeLocalRevenueIndex(uint256 _validatorId) external returns (uint256);
    function getEtherFiNodeVestedAuctionRewards(uint256 _validatorId) external returns (uint256);

    function getNonExitPenaltyAmount(uint256 _validatorId, uint32 _endTimestamp) external view returns (uint256);
    function getStakingRewards(uint256 _validatorId) external view returns (uint256, uint256, uint256, uint256);
    function getRewards(uint256 _validatorId, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) external view returns (uint256, uint256, uint256, uint256);
    function getFullWithdrawalPayouts(uint256 _validatorId) external view returns (uint256, uint256, uint256, uint256);
    function isExitRequested(uint256 _validatorId) external view returns (bool);

    // Non-VIEW functions
    function createEtherfiNode(uint256 _validatorId) external returns (address);
    function registerEtherFiNode(uint256 _validatorId, address _address) external;
    function unregisterEtherFiNode(uint256 _validatorId) external;

    function incrementNumberOfValidators(uint256 _count) external;

    function setEtherFiNodePhase(uint256 _validatorId, IEtherFiNode.VALIDATOR_PHASE _phase) external;
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId, string calldata _ipfs) external;
    function setEtherFiNodeLocalRevenueIndex(uint256 _validatorId, uint256 _localRevenueIndex) payable external;
    function sendExitRequest(uint256 _validatorId) external;
    function markExited(uint256[] calldata _validatorIds, uint32[] calldata _exitTimestamp) external;

    function partialWithdraw(uint256 _validatorId) external;
}
