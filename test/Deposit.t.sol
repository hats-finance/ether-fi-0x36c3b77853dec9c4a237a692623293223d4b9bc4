// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";

contract DepositTest is Test {
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

    function testDepositContractInstantiatedCorrectly() public {
        assertEq(depositInstance.stakeAmount(), 0.1 ether);
        assertEq(depositInstance.owner(), address(owner));
    }

    function testDepositCreatesNFTs() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
    }

    function testDepositCreatesNFTsWithCorrectOwner() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
    }

    function testDepositReceivesEther() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(address(depositInstance).balance, 0.1 ether);
    }

    function testDepositUpdatesBalancesMapping() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.1 ether
        );
        vm.stopPrank();
        hoax(address(depositInstance));
        auctionInstance.enableBidding();
        vm.stopPrank();
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.2 ether
        );
    }

    function testDepositDisablesBidding() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(auctionInstance.bidsEnabled(), false);        
    }

    function testDepositFailsIfIncorrectAmountSent() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        depositInstance.deposit{value: 0.2 ether}();
    }
}
