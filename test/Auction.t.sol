// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";

contract AuctionTest is Test {
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        auctionInstance = new Auction();
        depositInstance = new Deposit(address(auctionInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testAuctionContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfBids(), 1);
        assertEq(auctionInstance.owner(), address(owner));
        assertEq(
            auctionInstance.depositContractAddress(),
            address(depositInstance)
        );
    }

    function testBiddingHighestBidWorksCorrectly() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        (uint256 amount,,address bidderAddress,) = auctionInstance.bids(1);

        assertEq(amount, 0.1 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.numberOfBids(), 2);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        (uint256 amount2,, address bidderAddress2,) = auctionInstance.bids(
            auctionInstance.currentHighestBidId()
        );

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(amount2, 0.3 ether);
        assertEq(bidderAddress2, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.numberOfBids(), 3);

        assertEq(address(auctionInstance).balance, 0.4 ether);
    
    }
}
