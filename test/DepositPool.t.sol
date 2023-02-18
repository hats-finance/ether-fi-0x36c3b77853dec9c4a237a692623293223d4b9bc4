// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/DepositPool.sol";

contract DepositPoolTest is Test {
    event DurationSet(uint256 oldDuration, uint256 newDuration);

    DepositPool depositPoolInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositPoolInstance = new DepositPool();
        vm.stopPrank();
    }

    function test_DepositPoolWorksCorrectly() public {
        startHoax(owner);
        depositPoolInstance.deposit{value: 0.3 ether}();
        assertEq(depositPoolInstance.userBalance(owner), 0.3 ether);
        assertEq(depositPoolInstance.depositTimes(owner), 1);
        vm.warp(51);
        depositPoolInstance.withdraw();
        assertEq(depositPoolInstance.userBalance(owner), 0 ether);
        assertEq(depositPoolInstance.userPoints(owner), 150);
        assertEq(depositPoolInstance.depositTimes(owner), 0);
        vm.stopPrank();

        startHoax(alice);
        depositPoolInstance.deposit{value: 1.65 ether}();
        assertEq(depositPoolInstance.userBalance(alice), 1.65 ether);
        assertEq(depositPoolInstance.depositTimes(alice), 51);
        vm.warp(1305);
        depositPoolInstance.withdraw();
        assertEq(depositPoolInstance.userBalance(alice), 0 ether);
        assertEq(depositPoolInstance.userPoints(alice), 20691);
        assertEq(depositPoolInstance.depositTimes(alice), 0);
        vm.stopPrank();
    }

    function test_SetDurationWorks() public {
        assertEq(depositPoolInstance.duration(), 0);
        vm.prank(owner);
        depositPoolInstance.setDuration(3);
        assertEq(depositPoolInstance.duration(), 3);
    }

    function test_SetDurationEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit DurationSet(0, 3);
        vm.prank(owner);
        depositPoolInstance.setDuration(3);
    }
}
