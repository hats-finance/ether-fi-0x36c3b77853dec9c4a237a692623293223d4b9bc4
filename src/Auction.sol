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

    mapping(uint256 => AuctionDetails) public auctions;
    mapping(uint256 => mapping(address => Bid)) public bids;

    event AuctionCreated(uint256 startTime, uint256 auctionId);

    struct AuctionDetails {
        uint256 winningBid;
        uint256 startTime;
        uint256 timeClosed;
        address winningAddress;
        bool isActive;
    }

    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
    }

    constructor(address _depositAddress) {
        depositContractAddress = _depositAddress;
        owner = msg.sender;
    }

    //only called by deposit contract or owner
    function startAuction() external {

        require(msg.sender == owner || msg.sender == depositContractAddress, "Incorrect caller");

        auctions[numberofAuctions] = AuctionDetails({
            winningBid: 0,
            startTime: block.timestamp,
            timeClosed: 0,
            winningAddress: address(0),
            isActive: true
        });

        emit AuctionCreated(block.timestamp, numberofAuctions);
        numberofAuctions++;

    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }

    modifier onlyDepositContract() {
        require(msg.sender == depositContractAddress, "Only deposit contract function");
        _;
    }
}