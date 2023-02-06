// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {
    function refundBid(uint256 _amount, uint256 _bidId) external;
}
