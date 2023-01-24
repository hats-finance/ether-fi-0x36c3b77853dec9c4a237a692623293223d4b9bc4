// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITreasury {
    function withdraw() external;

    function refundBid(uint256 _amount, uint256 _bidId) external;

    function setAuctionContractAddress(address _auctionContractAddress)
        external;
}
