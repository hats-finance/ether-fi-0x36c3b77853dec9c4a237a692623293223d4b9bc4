// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IDeposit.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./Deposit.sol";

contract Auction {

    uint256 public numberofAuctions = 1;
    address public depositContractAddress;
    address public owner;

    mapping(uint256 => AuctionDetails) public auctions;
    mapping(uint256 => mapping(address => Bid)) public bids;
    mapping(address => uint256) public refundBalances;

    event AuctionCreated(uint256 auctionId, uint256 startTime);
    event AuctionClosed(uint256 auctionId, uint256 endTime);

    struct AuctionDetails {
        Bid winningBid;
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

    constructor(address _depositAddress) {
        depositContractAddress = _depositAddress;
        owner = msg.sender;
        startAuction();
    }

    function startAuction() public onlyOwnerOrDepositContract {

        auctions[numberofAuctions] = AuctionDetails({
            winningBid: bids[numberofAuctions][msg.sender],
            numberOfBids: 0,
            startTime: block.timestamp,
            timeClosed: 0,
            isActive: true
        });

        emit AuctionCreated(numberofAuctions, block.timestamp);
        numberofAuctions++;

    }

    //Owner cannot call this otherwise it poses a bias risk between bidder and owner
    function closeAuction() external onlyDepositContract returns (address) {
       
        AuctionDetails storage auctionDetails = auctions[numberofAuctions - 1];
        auctionDetails.isActive = false;
        auctionDetails.timeClosed = block.timestamp;

        emit AuctionClosed(numberofAuctions - 1, block.timestamp);

        Bid memory bid = auctionDetails.winningBid;
        return bid.bidderAddress;
    }

    //Future will have a whitelist of operators who can bid
    function bidOnStake() external payable {
        AuctionDetails storage currentAuction = auctions[numberofAuctions - 1];
        Bid memory bid = currentAuction.winningBid;

        require(currentAuction.isActive == true, "Auction is inactive");
        require(msg.value > bid.amount, "Bid too low");

        bids[numberofAuctions - 1][msg.sender] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender
        });

        currentAuction.numberOfBids++;
        refundBalances[bid.bidderAddress] += bid.amount;

        currentAuction.winningBid = bids[numberofAuctions - 1][msg.sender];

    }

    function claimRefundableBalance() external {
        
        uint256 refundBalance = refundBalances[msg.sender];
        refundBalances[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: refundBalance}("");
        require(sent, "Failed to send Ether");
    }

    modifier onlyOwnerOrDepositContract() {
        require(msg.sender == owner || msg.sender == depositContractAddress, "Not owner or deposit contract");
        _;
    }

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Only owner function");
    //     _;
    // }

    modifier onlyDepositContract() {
        require(msg.sender == depositContractAddress, "Only deposit contract function");
        _;
    }
}