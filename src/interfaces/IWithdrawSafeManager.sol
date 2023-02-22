// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafeManager {
    enum ValidatorRecipientType {
        TNFTHOLDER,
        BNFTHOLDER,
        TREASURY,
        OPERATOR
    }

    struct AuctionContractRevenueSplit {
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

    struct ValidatorStakingRewardSplit {
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

    function partialWithdraw(uint256 _validatorId) external;
    function partialWithdrawBatchForOperator(address _operator, uint256[] memory _validatorIds) external;
    function partialWithdrawBatchForOperatorAndTNftHolder(address _operator, address _tnftholder, uint256[] memory _validatorIds) external;

    function setWithdrawSafeAddress(uint256 _validatorId, address _safeAddress)
        external;

    function getWithdrawSafeAddress(uint256 _validatorId)
        external
        returns (address);
}
