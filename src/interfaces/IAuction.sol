// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {

    struct AuctionDetails {
        uint256 winningBidId;
        uint256 numberOfBids;
        uint256 startTime;
        uint256 timeClosed;
        bool isActive;
    }

    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
    }

    function startAuction() external;
    function closeAuction() external returns (address);
    function bidOnStake() external payable;
    function claimRefundableBalance() external;
    function setDepositContractAddress(address _depositContractAddress) external;

}