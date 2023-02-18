// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/DepositPool.sol";

contract DepositPoolTest is Test {
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawn(
        address indexed sender,
        uint256 amount,
        uint256 lengthOfDeposit
    );
    event DurationSet(uint256 oldDuration, uint256 newDuration);

    DepositPool depositPoolInstance;

    uint256 One_Day = 1 days;
    uint256 One_Month = 1 weeks * 4;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    function setUp() public {
        vm.startPrank(owner);
        depositPoolInstance = new DepositPool();
        vm.stopPrank();
    }

    function test_DepositPoolWorksCorrectly() public {
        startHoax(owner);
        depositPoolInstance.deposit{value: 0.1 ether}();
        assertEq(depositPoolInstance.userBalance(owner), 0.1 ether);
        assertEq(depositPoolInstance.depositTimes(owner), 1);

        // One minute
        vm.warp(61);
        depositPoolInstance.withdraw();

        assertEq(depositPoolInstance.userBalance(owner), 0 ether);
        assertEq(depositPoolInstance.userPoints(owner), 189);
        assertEq(depositPoolInstance.depositTimes(owner), 0);
        vm.stopPrank();

        startHoax(alice);
        depositPoolInstance.deposit{value: 1.65 ether}();
        assertEq(depositPoolInstance.userBalance(alice), 1.65 ether);
        assertEq(depositPoolInstance.depositTimes(alice), 61);

        // One day
        vm.warp(One_Day);
        depositPoolInstance.withdraw();

        assertEq(depositPoolInstance.userBalance(alice), 0 ether);
        assertEq(depositPoolInstance.userPoints(alice), 1108592);
        assertEq(depositPoolInstance.depositTimes(alice), 0);
        vm.stopPrank();
    }

    function test_DepositMinDeposit() public {
        vm.expectRevert("Incorrect Deposit Amount");
        hoax(alice);
        depositPoolInstance.deposit{value: 0.03 ether}();
    }

    function test_DepositMaxDeposit() public {
        vm.expectRevert("Incorrect Deposit Amount");
        hoax(alice);
        depositPoolInstance.deposit{value: 101 ether}();
    }

    function test_WithdrawMulitiplierWorks() public {
        hoax(alice);
        depositPoolInstance.deposit{value: 0.1 ether}();

        // Set multiplier duration to 1 month
        vm.prank(owner);
        depositPoolInstance.setDuration(1);

        console.logUint(block.timestamp);
        vm.warp(One_Month + 2);
        console.logUint(block.timestamp);

        vm.prank(alice);
        depositPoolInstance.withdraw();

        // one month + 2s rewards for 0.1 ether * 2
        assertEq(depositPoolInstance.userPoints(alice), 7644675 * 2);

        vm.prank(owner);
        depositPoolInstance.setDuration(2);

        hoax(bob);
        depositPoolInstance.deposit{value: 0.1 ether}();

        skip((One_Month * 2) + 2);

        vm.prank(bob);
        depositPoolInstance.withdraw();
        // two months + 2s rewards for 0.1 ether * 2
        assertEq(depositPoolInstance.userPoints(bob), 15289350 * 2);
    }

    function test_SetDurationWorks() public {
        assertEq(depositPoolInstance.duration(), 0);
        vm.prank(owner);
        depositPoolInstance.setDuration(1);
        assertEq(depositPoolInstance.duration(), One_Month);
    }

    function test_EventDeposit() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(address(alice), 0.3 ether);
        hoax(alice);
        depositPoolInstance.deposit{value: 0.3 ether}();
    }

    function test_EventWithdrawn() public {
        hoax(alice);
        depositPoolInstance.deposit{value: 0.1 ether}();

        vm.warp(One_Day);

        vm.expectEmit(false, false, false, true);
        emit Withdrawn(alice, 0.1 ether, One_Day - 1);
        hoax(alice);
        depositPoolInstance.withdraw();
    }

    function test_EventDurationSet() public {
        vm.expectEmit(false, false, false, true);
        emit DurationSet(0, One_Month * 3);
        vm.prank(owner);
        depositPoolInstance.setDuration(3);
    }
}
