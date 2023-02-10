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

    function receiveAuctionFunds(uint256 _validatorId) external payable;
    function setOperatorAddress(uint256 _validatorId, address _operatorAddress) external;
    function withdrawFunds(uint256 _validatorId) external;
}
