// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITreasury {
    function withdraw() external;

    function setAuctionContractAddress(address _auctionContractAddress)
        external;
}
