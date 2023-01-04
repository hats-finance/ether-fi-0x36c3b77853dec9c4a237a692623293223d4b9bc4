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
    uint256 public numberOfAuctions;
    address public depositContractAddress;
    address public owner;

    mapping(uint256 => AuctionDetails) public auctions;

    //Mapping of auction ID => bidID => Bid
    mapping(uint256 => mapping(uint256 => Bid)) public bids;
    mapping(address => uint256) public refundBalances;

    event AuctionCreated(uint256 auctionId, uint256 startTime);
    event AuctionClosed(uint256 auctionId, uint256 endTime);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event RefundClaimed(address claimer, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function startAuction() public onlyOwnerOrDepositContract {
        if (numberOfAuctions != 0) {
            require(
                auctions[numberOfAuctions - 1].isActive == false,
                "Previous auction not closed"
            );
        }

        auctions[numberOfAuctions] = AuctionDetails({
            winningBidId: 0,
            numberOfBids: 0,
            startTime: block.timestamp,
            timeClosed: 0,
            isActive: true
        });

        emit AuctionCreated(numberOfAuctions, block.timestamp);
        numberOfAuctions++;
    }

    //Owner cannot call this otherwise it poses a bias risk between bidder and owner
    function closeAuction() external onlyDepositContract returns (address) {
        AuctionDetails storage auctionDetails = auctions[numberOfAuctions - 1];
        auctionDetails.isActive = false;
        auctionDetails.timeClosed = block.timestamp;

        emit AuctionClosed(numberOfAuctions - 1, block.timestamp);

        uint256 winningBidID = auctionDetails.winningBidId;
        Bid memory bid = bids[numberOfAuctions - 1][winningBidID];
        return bid.bidderAddress;
    }

    //Future will have a whitelist of operators who can bid
    function bidOnStake() external payable {
        AuctionDetails storage currentAuction = auctions[numberOfAuctions - 1];
        Bid memory bid = bids[numberOfAuctions - 1][
            currentAuction.winningBidId
        ];

        require(currentAuction.isActive == true, "Auction is inactive");
        require(msg.value > bid.amount, "Bid too low");

        bids[numberOfAuctions - 1][currentAuction.numberOfBids] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender
        });

        currentAuction.numberOfBids++;
        refundBalances[bid.bidderAddress] += bid.amount;

        currentAuction.winningBidId = currentAuction.numberOfBids - 1;

        emit BidPlaced(numberOfAuctions - 1, msg.sender, msg.value);
    }

    function claimRefundableBalance() external {
        require(refundBalances[msg.sender] > 0, "No refund available");

        uint256 refundBalance = refundBalances[msg.sender];
        refundBalances[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: refundBalance}("");
        require(sent, "Failed to send Ether");

        emit RefundClaimed(msg.sender, refundBalance);
    }

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
