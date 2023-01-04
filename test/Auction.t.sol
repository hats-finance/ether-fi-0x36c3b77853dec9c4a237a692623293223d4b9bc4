// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/interfaces/IAuction.sol";

contract AuctionTest is Test {

    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    IAuction public auctionInterfaceInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositInstance = new Deposit();
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        auctionInstance = new Auction(address(depositInstance));
        auctionInterfaceInstance = IAuction(address(auctionInstance));
        vm.stopPrank();
    }

    function testAuctionContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfAuctions(), 2);
        assertEq(auctionInstance.owner(), address(owner));
        assertEq(auctionInstance.depositContractAddress(), address(depositInstance));
    }

    function testAuctionGetsCreatedOnInstantiation() public {
        (,, uint256 startTime,,) = auctionInstance.auctions(1);
        assertEq(startTime, 1);
    }
}