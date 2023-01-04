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