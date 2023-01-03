// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";

contract DepositTest is Test {

    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositInstance = new Deposit();
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testDepositCreatesNFTs() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(TestBNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 1);
        assertEq(TestTNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 1);
    }

    function testDepositCreatesNFTsWithCorrectOwner() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(TestBNFTInstance.ownerOf(0), 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(TestTNFTInstance.ownerOf(0), 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    }

    function testDepositReceivesEther() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(address(depositInstance).balance, 0.1 ether);
    }

     function testDepositUpdatesBalancesMapping() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(depositInstance.depositorBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.1 ether);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(depositInstance.depositorBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.2 ether);
    }

    function testDepositFailsIfIncorrectAmountSent() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        depositInstance.deposit{value:0.2 ether}();
    }
    
    function testUpdateStakeAmount() public {
        vm.startPrank(owner);
        assertEq(depositInstance.stakeAmount(), 0.1 ether);
        depositInstance.setStakeAmount(1 ether);
        assertEq(depositInstance.stakeAmount(), 1 ether);
    }

    function testUpdateStakeAmountFailsIfNotOwner() public {
        vm.expectRevert("Only owner function");
        vm.prank(alice);
        depositInstance.setStakeAmount(1 ether);
    }
}