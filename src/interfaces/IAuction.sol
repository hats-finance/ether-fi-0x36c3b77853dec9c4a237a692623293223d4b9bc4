// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {

    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
    }

    function bidOnStake() external payable;

    function disableBidding() external returns (address);

    function enableBidding() external;

    function updateBid(uint256 _bidId) external;

    function cancelBid(uint256 _bidId) external;

    function setDepositContractAddress(address _depositContractAddress)
        external;
}
