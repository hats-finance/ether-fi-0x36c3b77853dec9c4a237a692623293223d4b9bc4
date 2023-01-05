// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IAuction.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./Deposit.sol";

contract Auction is IAuction {
    //uint256 public numberOfAuctions;
    address public depositContractAddress;
    address public owner;

    uint256 public currentHighestBidId;
    uint256 public numberOfBids = 1;

    bool public bidsEnabled;

    mapping(uint256 => AuctionDetails) public auctions;
    mapping(address => mapping(uint256 => Bid)) public bids;
    //mapping(address => uint256) public refundBalances;

    //event AuctionCreated(uint256 auctionId, uint256 startTime);
    //event AuctionClosed(uint256 auctionId, uint256 endTime);
    event BidPlaced(address bidder, uint256 amount, uint256 bidderId);
    //event RefundClaimed(address claimer, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    // function startAuction() public onlyOwnerOrDepositContract {
    //     if (numberOfAuctions != 0) {
    //         require(
    //             auctions[numberOfAuctions - 1].isActive == false,
    //             "Previous auction not closed"
    //         );
    //     }

    //     auctions[numberOfAuctions] = AuctionDetails({
    //         winningBidId: 0,
    //         numberOfBids: 0,
    //         startTime: block.timestamp,
    //         timeClosed: 0,
    //         isActive: true
    //     });

    //     emit AuctionCreated(numberOfAuctions, block.timestamp);
    //     numberOfAuctions++;
    // }

    //Owner cannot call this otherwise it poses a bias risk between bidder and owner
    // function closeAuction() external onlyDepositContract returns (address) {
    //     AuctionDetails storage auctionDetails = auctions[numberOfAuctions - 1];
    //     auctionDetails.isActive = false;
    //     auctionDetails.timeClosed = block.timestamp;

    //     emit AuctionClosed(numberOfAuctions - 1, block.timestamp);

    //     uint256 winningBidID = auctionDetails.winningBidId;
    //     Bid memory bid = bids[numberOfAuctions - 1][winningBidID];
    //     return bid.bidderAddress;
    // }

    function disableBidding() external onlyDepositContract {
        require(bidsEnabled == true, "Bids already disabled");
        bidsEnabled = false;
    }

    function enableBidding() external onlyDepositContract {
        require(bidsEnabled == false, "Bids already enabled");
        bidsEnabled = true;
    }

    function cancelBid(uint256 _bidId) external {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        bids[_bidId].isActive = false;

        if(currentHighestBidId == _bidId) {
            uint256 tempWinningBidId;

            for(uint256 x = 1; x <= numberOfBids; x++){
                if((bids[x].amount > bids[tempWinningBidId].amount) && (bids[x].isActive == true)){
                    tempWinningBidId = x;
                }
            }

            currentHighestBidId = tempWinningBidId;
        }

        uint256 bidValue = bids[_bidId].amount;

        (bool sent, ) = msg.sender.call{value: bidValue}("");
        require(sent, "Failed to send Ether");

    }

    //Future will have a whitelist of operators who can bid
    function bidOnStake() external payable {

        require(bidsEnabled == true, "Bidding is on hold");
        //require(msg.value > bid.amount, "Bid too low");

        bids[numberOfBids] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender
        });

        if(msg.value > bids[currentHighestBidId].amount) {
            currentHighestBidId = numberOfBids;
        }

        //currentAuction.numberOfBids++;
        //refundBalances[bid.bidderAddress] += bid.amount;

        //currentAuction.winningBidId = currentAuction.numberOfBids - 1;

        numberOfBids++;

        emit BidPlaced(msg.sender, msg.value, numberOfBids - 1);
    }

    // function claimRefundableBalance() external {
    //     require(refundBalances[msg.sender] > 0, "No refund available");

    //     uint256 refundBalance = refundBalances[msg.sender];
    //     refundBalances[msg.sender] = 0;

    //     (bool sent, ) = msg.sender.call{value: refundBalance}("");
    //     require(sent, "Failed to send Ether");

    //     emit RefundClaimed(msg.sender, refundBalance);
    // }

    function setDepositContractAddress(address _depositContractAddress)
        external
    {
        depositContractAddress = _depositContractAddress;
    }

    modifier onlyOwnerOrDepositContract() {
        require(
            msg.sender == owner || msg.sender == depositContractAddress,
            "Not owner or deposit contract"
        );
        _;
    }

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Only owner function");
    //     _;
    // }

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}
