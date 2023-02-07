// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {
    function refundBid(uint256 _amount, uint256 _bidId) external;

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

    struct ValidatorFundRecipients {
        address tnftHolder;
        address bnftHolder;
        address operator;
    }

    function setUpValidatorData(uint256 _validatorId, address _staker, address _operator) external;
    function receiveAuctionFunds(uint256 _validatorId) external payable;

}
