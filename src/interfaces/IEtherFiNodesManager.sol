// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

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

    function createWithdrawalSafe() external returns (address);

    function receiveAuctionFunds(uint256 _validatorId, uint256 _amount)
        external;

    function setOperatorAddress(uint256 _validatorId, address _operatorAddress)
        external;

    function withdrawFunds(uint256 _validatorId) external;

    function setEtherFiNodeAddress(uint256 _validatorId, address _safeAddress)
        external;

    function getEtherFiNodeAddress(uint256 _validatorId)
        external
        returns (address);
}
