// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";

contract ScenarioTest is Test {
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        auctionInstance = new Auction(address(treasuryInstance));
        depositInstance = new Deposit(address(auctionInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    /**
     *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  One deposit - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     */
    function scenarioOne() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        assertEq(address(auctionInstance).balance, 0.3 ether);
        assertEq(address(depositInstance).balance, 0);
        
        (uint256 amount,, address bidderAddress, bool isActiveBeforeStake) = auctionInstance.bids(auctionInstance.currentHighestBidId());

        assertEq(auctionInstance.numberOfBids() - 1, 1);
        assertEq(amount, 0.3 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.bidsEnabled(), true);
        assertEq(isActiveBeforeStake, true);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(address(depositInstance).balance, 0.1 ether);
        assertEq(address(auctionInstance).balance, 0.3 ether);
        assertEq(auctionInstance.bidsEnabled(), false);

        (,,, bool isActiveAfterStake) = auctionInstance.bids(1);
        assertEq(isActiveAfterStake, false);
    }

    /**
     *  Three bids - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf, 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
     *  One bid cancel - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  One deposit - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Attempted Bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Fourth Bid - 0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098
     *  UpdatedBid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  Second deposit - 0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
     */
    function scenarioTwo() public {
        
        //Bid One
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        //Bid Two
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.4 ether}();

        //Bid Three
        hoax(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20);
        auctionInstance.bidOnStake{value: 0.7 ether}();

        //Bid cancelled
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);

        //Deposit One
        depositInstance.deposit{value: 0.1 ether}();

        //Attempted bid which should fail
        vm.expectRevert("Bidding is on hold");
        auctionInstance.bidOnStake{value: 0.3 ether}();
        vm.stopPrank();

        //Bid Four
        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.bidOnStake{value: 0.4 ether}();

        //Bid updated
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.updateBid{value: 0.9 ether}(1);

        //Deposit Two
        hoax(0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f);
        depositInstance.deposit{value: 0.1 ether}();
    }
 }
