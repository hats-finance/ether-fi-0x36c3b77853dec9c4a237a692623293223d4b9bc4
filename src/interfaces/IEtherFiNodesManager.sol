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

    struct AuctionManagerContractRevenueSplit {
        uint256 treasurySplit;
        uint256 nodeOperatorSplit;
        uint256 tnftHolderSplit;
        uint256 bnftHolderSplit;
    }

    struct ValidatorExitRevenueSplit {
        uint256 treasurySplit;
        uint256 nodeOperatorSplit;
        uint256 tnftHolderSplit;
        uint256 bnftHolderSplit;
    }

    function getEtherFiNodeAddress(uint256 _validatorId) external view returns (address);
    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory);

    function installEtherFiNode(uint256 _validatorId, address _safeAddress) external;
    function uninstallEtherFiNode(uint256 _validatorId) external;
    function setEtherFiNodePhase(uint256 _validatorId, IEtherFiNode.VALIDATOR_PHASE _phase) external;
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId, string calldata _ipfs) external;

    function createEtherfiNode(uint256 _validatorId) external returns (address);
    function receiveAuctionFunds(uint256 _validatorId, uint256 _amount)
        external;
    function withdrawFunds(uint256 _validatorId) external;
}
