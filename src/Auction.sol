// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IDeposit.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./Deposit.sol";

contract Auction {

    uint256 public numberofAuctions;
    address public depositContractAddress;
    address public owner;

    mapping(uint256 => Auction) public auctions;

    struct Auction {
        uint256 reservePrice;
        uint256 winningBid;
        uint256 startTime;
        uint256 timeClosed;
        address winningAddress;
        bool isActive;
    }

    constructor(address _depositAddress) {
        depositContractAddress = _depositAddress;
        owner = msg.sender;
    }

    //only called by deposit contract or owner
    function startAuction() external {

        auctions[numberofAuctions] = Auction({
            reservePrice: 0,
            winningBid: 0,
            startTime: block.timestamp,
            timeClosed: 0,
            winningAddress: address(0),
            isActive: true
        });

        numberofAuctions++;

    }

}