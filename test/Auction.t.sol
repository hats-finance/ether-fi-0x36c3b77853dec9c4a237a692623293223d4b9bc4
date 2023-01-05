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
    
    function testEnablingBiddingFailsIfBiddingAlreadyEnabled() public {
        hoax(address(depositInstance));
        vm.expectRevert("Bids already enabled");
        auctionInstance.enableBidding();  
    }

    function testEnablingBiddingFailsIfNotContractCalling() public {
        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.enableBidding();  
    }

    function testEnablingBiddingWorks() public {
        assertEq(auctionInstance.bidsEnabled(), true);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        assertEq(auctionInstance.bidsEnabled(), false);

        hoax(address(depositInstance));
        auctionInstance.enableBidding();  

        assertEq(auctionInstance.bidsEnabled(), true);
    }

    function testDisableBiddingFailsIfBiddingAlreadyDisabled() public {
        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(address(depositInstance));
        vm.expectRevert("Bids already disabled");
        auctionInstance.disableBidding();  
    }

    function testDisablingBiddingFailsIfNotContractCalling() public {
        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.disableBidding();  
    }

    function testDisablingBiddingWorks() public {
        assertEq(auctionInstance.bidsEnabled(), true);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();
        assertEq(auctionInstance.currentHighestBidId(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}();
        assertEq(auctionInstance.currentHighestBidId(), 2);

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}();
        assertEq(auctionInstance.currentHighestBidId(), 2);

        hoax(address(depositInstance));
        address winner = auctionInstance.disableBidding();

        (,,,bool isActiveBid1) = auctionInstance.bids(1);
        (,,,bool isActiveBid2) = auctionInstance.bids(2);
        (,,,bool isActiveBid3) = auctionInstance.bids(3);

        assertEq(auctionInstance.bidsEnabled(), false);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid2, false);
        assertEq(isActiveBid3, true);
        assertEq(winner, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    }

    function testBiddingFailsWhenBidsDisabled() public {
        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bidding is on hold");
        auctionInstance.bidOnStake{value: 0.1 ether}();    
    }

    function testBiddingWorksCorrectly() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        assertEq(auctionInstance.currentHighestBidId(), 1);

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

    function testCancelBidFailsWhenBidAlreadyInactive() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);    
        
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(1);    
    }

    function testCancelBidFailsWhenNotBidOwnerCalling() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);    
    }

    function testCancelBidFailsWhenNotExistingBid() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);    
    }

    function testCancelBidWorksIfBidIsNotCurrentHighest() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}();
        assertEq(address(auctionInstance).balance, 0.6 ether);

        uint256 balanceBeforeCancellation = 0xCDca97f61d8EE53878cf602FF6BC2f260f10240B.balance;
        auctionInstance.cancelBid(3);

        (,,,bool isActive) = auctionInstance.bids(3);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B.balance, balanceBeforeCancellation += 0.2 ether);
    }

    function testCancelBidWorksIfBidIsCurrentHighest() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}();
        assertEq(address(auctionInstance).balance, 0.6 ether);
        
        assertEq(auctionInstance.currentHighestBidId(), 2);

        uint256 balanceBeforeCancellation = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf.balance;

        vm.stopPrank();
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);
        assertEq(auctionInstance.currentHighestBidId(), 3);

        (,,,bool isActive) = auctionInstance.bids(2);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.3 ether);
    }

    function testUpdateBidFailsWhenNotExistingBid() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Invalid bid");
        auctionInstance.updateBid{value: 0.1 ether}(1);   
    }

    function testUpdateBidFailsWhenNotBidOwnerCalling() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();
        
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Invalid bid");
        auctionInstance.updateBid{value: 0.1 ether}(1);   
    }

    function testUpdateBidFailsWhenBidAlreadyInactive() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);   
        
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.updateBid{value: 0.1 ether}(1);   
    }

    function testUpdateBidWorks() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}();

        assertEq(auctionInstance.currentHighestBidId(), 2);
        
        assertEq(address(auctionInstance).balance, 0.6 ether);

        auctionInstance.updateBid{value: 0.2 ether}(3);

        (uint256 amount,,,) = auctionInstance.bids(3);

        assertEq(amount, 0.4 ether);
        assertEq(address(auctionInstance).balance, 0.8 ether);
        assertEq(auctionInstance.currentHighestBidId(), 3);
    }
}
