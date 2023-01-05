// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {

    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
    }

    function startAuction() external;

    function closeAuction() external returns (address);

    function bidOnStake() external payable;

    function claimRefundableBalance() external;

    function setDepositContractAddress(address _depositContractAddress)
        external;
}
