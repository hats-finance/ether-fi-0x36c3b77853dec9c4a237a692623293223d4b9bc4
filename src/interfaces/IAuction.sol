// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {

    function startAuction() external;
    function closeAuction() external returns (address);
    function bidOnStake() external;
    function claimRefundableBalance() external;
}