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
    address public depositContractAddress;
    address public owner;

    uint256 public currentHighestBidId;
    uint256 public numberOfBids = 1;

    bool public bidsEnabled;

    mapping(uint256 => Bid) public bids;

    event BidPlaced(address bidder, uint256 amount, uint256 bidderId);
    event BiddingDisabled(address winner);
    event BiddingEnabled();
    event BidCancelled(uint256 bidId);

    constructor() {
        owner = msg.sender;
        bidsEnabled = true;
    }

    function disableBidding() external onlyDepositContract returns (address){
        require(bidsEnabled == true, "Bids already disabled");
        bidsEnabled = false;
        bids[currentHighestBidId].isActive = false;
        address winningOperator = bids[currentHighestBidId].bidderAddress;
        
        uint256 tempWinningBidId;

        for(uint256 x = 1; x <= numberOfBids; x++){
            if((bids[x].amount > bids[tempWinningBidId].amount) && (bids[x].isActive == true)){
                tempWinningBidId = x;
            }
        }

        currentHighestBidId = tempWinningBidId;
        emit BiddingDisabled(winningOperator);
        return winningOperator;
    }

    function enableBidding() external onlyDepositContract {
        require(bidsEnabled == false, "Bids already enabled");
        bidsEnabled = true;
        emit BiddingEnabled();
    }

    function updateBid(uint256 _bidId) external {

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

        emit BidCancelled(_bidId);

    }

    //Future will have a whitelist of operators who can bid
    function bidOnStake() external payable {

        require(bidsEnabled == true, "Bidding is on hold");

        bids[numberOfBids] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender,
            isActive: true
        });

        if(msg.value > bids[currentHighestBidId].amount) {
            currentHighestBidId = numberOfBids;
        }

        numberOfBids++;

        emit BidPlaced(msg.sender, msg.value, numberOfBids - 1);
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

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}
