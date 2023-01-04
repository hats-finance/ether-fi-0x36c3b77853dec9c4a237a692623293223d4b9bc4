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
        depositInstance = new Deposit();
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        auctionInstance = new Auction(address(depositInstance));
        vm.stopPrank();
    }

    function testAuctionContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfAuctions(), 2);
        assertEq(auctionInstance.owner(), address(owner));
        assertEq(auctionInstance.depositContractAddress(), address(depositInstance));
    }

    function testStartAuctionFailsIfPreviousAuctionIsOpen() public {
        vm.startPrank(owner);
        vm.expectRevert("Previous auction not closed");
        auctionInstance.startAuction();
    }

    function testStartAuctionFailsIfNotOwnerOrDepositContract() public {
        vm.startPrank(alice);
        vm.expectRevert("Not owner or deposit contract");
        auctionInstance.startAuction();
    }

    function testStartAuctionFunctionCreatesNewAuction() public {
        hoax(address(depositInstance));
        auctionInstance.closeAuction();
        vm.startPrank(owner);
        auctionInstance.startAuction();
        assertEq(auctionInstance.numberOfAuctions(), 3);
    }

    function testCloseAuctionFailsIfNotDepositContract() public {
        vm.startPrank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.closeAuction();
    }

    function testCloseAuctionFunctionCorrectlyClosesAuction() public {
        hoax(address(depositInstance));
        auctionInstance.closeAuction();
        (,,,, bool isActive) = auctionInstance.auctions(1);
        assertEq(isActive, false);
    }

    function testCannotBidIfAuctionIsInactive() public {
        hoax(address(depositInstance));
        auctionInstance.closeAuction();

        vm.startPrank(alice);
        vm.expectRevert("Auction is inactive");
        auctionInstance.bidOnStake();
    }

    function testBiddingHighestBidWorksCorrectly() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();
        
        (uint256 amount,, address bidderAddress) = auctionInstance.bids(1, 0);
        (, uint256 numberOfBids,,,) = auctionInstance.auctions(1);

        assertEq(amount, 0.1 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(numberOfBids, 1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}();

        (uint256 amount2,, address bidderAddress2) = auctionInstance.bids(1, 1);
        (uint256 winningId, uint256 numberOfBids2,,,) = auctionInstance.auctions(1);

        assertEq(amount2, 0.3 ether);
        assertEq(bidderAddress2, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(numberOfBids2, 2);
        assertEq(winningId, 1);

        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.1 ether);
    }

    function testBiddingLowerThanWinningBidFails() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        vm.expectRevert("Bid too low");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.01 ether}();
    }

    function testClaimRefundFailsIfNoRefundAvailable() public {
        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        vm.expectRevert("No refund available");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.claimRefundableBalance();
    }

    function testClaimRefundCorrectlySendsRefund() public {
        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();
        auctionInstance.bidOnStake{value: 0.2 ether}();

        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.1 ether);
        assertEq(address(auctionInstance).balance, 0.3 ether);

        uint256 currentTestAccountBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance;

        auctionInstance.claimRefundableBalance();

        assertEq(address(auctionInstance).balance, 0.2 ether);
        assertEq(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance, currentTestAccountBalance += 0.1 ether);
        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);

    }
}