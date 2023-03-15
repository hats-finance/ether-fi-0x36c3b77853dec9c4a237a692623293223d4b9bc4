// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/Treasury.sol";
import "../src/AuctionManager.sol";
import "../src/NodeOperatorKeyManager.sol";

contract TreasuryTest is Test {
    Treasury treasuryInstance;
    AuctionManager auctionInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(address(nodeOperatorKeyManagerInstance));
        vm.stopPrank();
    }

    function test_TreasuryCanReceiveFunds() public {
        assertEq(address(treasuryInstance).balance, 0);
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(treasuryInstance).call{value: 0.5 ether}("");
        assertEq(address(treasuryInstance).balance, 0.5 ether);
    }

    function test_WithdrawFailsIfNotOwner() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(treasuryInstance).call{value: 0.5 ether}("");

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        treasuryInstance.withdraw(0);
    }

    function test_WithdrawWorks() public {
        assertEq(address(treasuryInstance).balance, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(treasuryInstance).call{value: 0.5 ether}("");
        assertEq(address(treasuryInstance).balance, 0.5 ether);

        vm.prank(owner);
        vm.expectRevert("the balance is lower than the requested amount");
        treasuryInstance.withdraw(0.5 ether + 1);

        vm.prank(owner);
        treasuryInstance.withdraw(0.5 ether);

        assertEq(address(owner).balance, 0.5 ether);
        assertEq(address(treasuryInstance).balance, 0);
    }
}
