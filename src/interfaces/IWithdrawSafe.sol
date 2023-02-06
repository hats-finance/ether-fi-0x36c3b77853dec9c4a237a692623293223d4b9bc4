// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {

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

    function setUpValidatorData(uint256 _validatorId, address _tnftHolder, address _bnftHolder, address _operator) external;
    function receiveAuctionFunds(uint256 _validatorId) external payable;

}
