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

    struct StakingRewardsSplit {
        uint64 treasury;
        uint64 nodeOperator;
        uint64 tnft;
        uint64 bnft;
    }

    struct ValidatorExitRevenueSplit {
        uint256 treasurySplit;
        uint256 nodeOperatorSplit;
        uint256 tnftHolderSplit;
        uint256 bnftHolderSplit;
    }

    function generateWithdrawalCredentials(
        address _address
    ) external view returns (bytes memory);

    function getEtherFiNodeAddress(
        uint256 _validatorId
    ) external view returns (address);

    function getEtherFiNodePhase(
        uint256 _validatorId
    ) external view returns (IEtherFiNode.VALIDATOR_PHASE phase);

    function getEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId
    ) external view returns (string memory);

    function getEtherFiNodeLocalRevenueIndex(
        uint256 _validatorId
    ) external returns (uint256);

    function getEtherFiNodeVestedAuctionRewards(
        uint256 _validatorId
    ) external returns (uint256);

    function getWithdrawalCredentials(
        uint256 _validatorId
    ) external view returns (bytes memory);

    function getNumberOfValidators() external view returns (uint256);

    function getNonExitPenaltyAmount(uint256 _validatorId) external view returns (uint256);
    function getNonExitPenaltyAmount(uint256 _validatorId, uint32 _endTimestamp) external view returns (uint256);
    function getStakingRewards(uint256 _validatorId) external view returns (uint256, uint256, uint256, uint256);
    function getFullWithdrawalPayouts(uint256 _validatorId) external view returns (uint256, uint256, uint256, uint256);

    function incrementNumberOfValidators(uint256 _count) external;

    function installEtherFiNode(
        uint256 _validatorId,
        address _safeAddress
    ) external;

    function uninstallEtherFiNode(uint256 _validatorId) external;

    function setEtherFiNodePhase(
        uint256 _validatorId,
        IEtherFiNode.VALIDATOR_PHASE _phase
    ) external;

    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId,
        string calldata _ipfs
    ) external;

    function setEtherFiNodeLocalRevenueIndex(
        uint256 _validatorId,
        uint256 _localRevenueIndex
    ) external;

    function sendExitRequest(uint256 _validatorId) external;

    function isExitRequested(uint256 _validatorId) external view returns (bool);
    function markExited(uint256[] calldata _validatorIds, uint32[] calldata _exitTimestamp) external;

    function createEtherfiNode(uint256 _validatorId) external returns (address);
    function partialWithdraw(uint256 _validatorId) external;
}
