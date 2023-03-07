// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITreasury {
    function withdraw() external;

    function setAuctionManagerContractAddress(address _auctionContractAddress)
        external;
}
