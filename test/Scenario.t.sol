// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";

contract ScenarioTest is Test {

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

    function testOneBidderWithOneStake() public {

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}();

        assertEq(auctionInstance.refundBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);
        assertEq(address(auctionInstance).balance, 0.1 ether);
        assertEq(address(depositInstance).balance, 0);

        (uint256 winningBidId, uint256 numberOfBids,,, bool isActive) = auctionInstance.auctions(auctionInstance.numberOfAuctions() - 1);
        (uint256 amount,, address bidderAddress) = auctionInstance.bids(auctionInstance.numberOfAuctions() - 1, winningBidId);

        assertEq(winningBidId, 0);
        assertEq(numberOfBids, 1);
        assertEq(amount, 0.1 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);

        depositInstance.deposit{value: 0.1 ether}();
        assertEq(TestBNFTInstance.ownerOf(0), 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(TestTNFTInstance.ownerOf(0), 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(address(depositInstance).balance, 0.1 ether);

    }
}