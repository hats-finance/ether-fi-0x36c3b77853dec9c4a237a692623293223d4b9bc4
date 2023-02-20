// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/DepositPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./TestERC20.sol";

contract DepositPoolTest is Test {
    event Deposit(address indexed sender, uint256 amount);
    event Withdrawn(
        address indexed sender,
        uint256 amount,
        uint256 lengthOfDeposit
    );
    event DurationSet(uint256 oldDuration, uint256 newDuration);

    DepositPool depositPoolInstance;

    TestERC20 public rETH;
    TestERC20 public stETH;
    TestERC20 public frxETH;

    uint256 One_Day = 1 days;
    uint256 One_Month = 1 weeks * 4;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    function setUp() public {
        rETH = new TestERC20("Rocket Pool ETH", "rETH");
        rETH.mint(alice, 10e18);
        rETH.mint(bob, 10e18);

        stETH = new TestERC20("Staked ETH", "stETH");
        stETH.mint(alice, 10e18);
        stETH.mint(bob, 10e18);

        frxETH = new TestERC20("Frax ETH", "frxETH");
        frxETH.mint(alice, 10e18);
        frxETH.mint(bob, 10e18);

        vm.startPrank(owner);
        depositPoolInstance = new DepositPool(
            address(rETH),
            address(stETH),
            address(frxETH)
        );
        vm.stopPrank();
    }

    function test_SetUp() public {
        assertEq(rETH.balanceOf(alice), 10e18);
        assertEq(stETH.balanceOf(alice), 10e18);
        assertEq(frxETH.balanceOf(alice), 10e18);
    }

    function test_DepositIntoDepositPool() public {
        vm.startPrank(alice);
        rETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(rETH), 1e17);
        vm.stopPrank();

        assertEq(depositPoolInstance.userBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_stETHBalance(alice), 0);
        assertEq(depositPoolInstance.userTo_frxETHBalance(alice), 0);
        assertEq(depositPoolInstance.depositTimes(alice), 1);

        vm.startPrank(alice);
        stETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(stETH), 1e17);
        vm.stopPrank();

        assertEq(depositPoolInstance.userBalance(alice), 0.2 ether);
        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_stETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_frxETHBalance(alice), 0);

        assertEq(rETH.balanceOf(address(depositPoolInstance)), 1e17);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 1e17);

        vm.startPrank(alice);
        frxETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(frxETH), 1e17);
        vm.stopPrank();

        assertEq(depositPoolInstance.userBalance(alice), 0.3 ether);
        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_stETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_frxETHBalance(alice), 0.1 ether);

        assertEq(rETH.balanceOf(address(depositPoolInstance)), 1e17);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 1e17);
        assertEq(frxETH.balanceOf(address(depositPoolInstance)), 1e17);
    }

    function test_DepositPoolWorksCorrectly() public {
        vm.startPrank(bob);
        stETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(stETH), 0.1 ether);
        assertEq(depositPoolInstance.userBalance(bob), 0.1 ether);
        assertEq(depositPoolInstance.userTo_stETHBalance(bob), 0.1 ether);
        assertEq(depositPoolInstance.depositTimes(bob), 1);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 0.1 ether);

        // One minute
        vm.warp(61);
        depositPoolInstance.withdraw();

        assertEq(depositPoolInstance.userBalance(bob), 0 ether);
        assertEq(depositPoolInstance.userPoints(bob), 189);
        assertEq(depositPoolInstance.depositTimes(bob), 0);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 0);
        vm.stopPrank();

        vm.startPrank(alice);
        rETH.approve(address(depositPoolInstance), 1.65 ether);
        depositPoolInstance.deposit(address(rETH), 1.65 ether);

        assertEq(depositPoolInstance.userBalance(alice), 1.65 ether);
        assertEq(depositPoolInstance.depositTimes(alice), 61);
        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 1.65 ether);
        assertEq(rETH.balanceOf(address(depositPoolInstance)), 1.65 ether);

        // One day
        vm.warp(One_Day);
        depositPoolInstance.withdraw();

        assertEq(depositPoolInstance.userBalance(alice), 0 ether);
        assertEq(depositPoolInstance.userPoints(alice), 1108592);
        assertEq(depositPoolInstance.depositTimes(alice), 0);
        assertEq(rETH.balanceOf(address(depositPoolInstance)), 0);
        vm.stopPrank();
    }

    function test_DepositPoolMinDeposit() public {
        vm.expectRevert("Incorrect Deposit Amount");
        hoax(alice);
        depositPoolInstance.deposit(address(rETH), 0.003 ether);
    }

    function test_DepositPoolMaxDeposit() public {
        vm.expectRevert("Incorrect Deposit Amount");
        hoax(alice);
        depositPoolInstance.deposit(address(rETH), 101 ether);
    }

    function test_WithdrawWorks() public {
        vm.startPrank(alice);
        frxETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(frxETH), 0.1 ether);

        stETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(stETH), 0.1 ether);

        rETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(rETH), 0.1 ether);
        vm.stopPrank();

        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_stETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userTo_frxETHBalance(alice), 0.1 ether);
        assertEq(depositPoolInstance.userBalance(alice), 0.3 ether);

        assertEq(rETH.balanceOf(address(depositPoolInstance)), 0.1 ether);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 0.1 ether);
        assertEq(frxETH.balanceOf(address(depositPoolInstance)), 0.1 ether);

        vm.prank(owner);
        depositPoolInstance.setDuration(1);

        vm.warp(One_Month + 2);

        uint256 aliceRethBalBefore = rETH.balanceOf(alice);
        uint256 aliceSTethBalBefore = stETH.balanceOf(alice);
        uint256 aliceFRXethBalBefore = frxETH.balanceOf(alice);

        vm.prank(alice);
        depositPoolInstance.withdraw();

        uint256 aliceRethBalAfter = rETH.balanceOf(alice);
        uint256 aliceSTethBalAfter = stETH.balanceOf(alice);
        uint256 aliceFRXethBalAfter = frxETH.balanceOf(alice);

        assertEq(depositPoolInstance.userTo_rETHBalance(alice), 0);
        assertEq(depositPoolInstance.userTo_stETHBalance(alice), 0);
        assertEq(depositPoolInstance.userTo_frxETHBalance(alice), 0);
        assertEq(depositPoolInstance.userBalance(alice), 0);

        assertEq(rETH.balanceOf(address(depositPoolInstance)), 0);
        assertEq(stETH.balanceOf(address(depositPoolInstance)), 0);
        assertEq(frxETH.balanceOf(address(depositPoolInstance)), 0);

        assertEq(aliceRethBalAfter, aliceRethBalBefore + 0.1 ether);
        assertEq(aliceSTethBalAfter, aliceSTethBalBefore + 0.1 ether);
        assertEq(aliceFRXethBalAfter, aliceFRXethBalBefore + 0.1 ether);
    }

    function test_WithdrawMulitiplierWorks() public {
        vm.startPrank(alice);
        frxETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(frxETH), 0.1 ether);
        vm.stopPrank();

        // Set multiplier duration to 1 month
        vm.prank(owner);
        depositPoolInstance.setDuration(1);

        // console.logUint(block.timestamp);
        vm.warp(One_Month + 2);
        // console.logUint(block.timestamp);

        vm.prank(alice);
        depositPoolInstance.withdraw();

        // one month + 2s rewards for 0.1 ether * 2
        assertEq(depositPoolInstance.userPoints(alice), 7644675 * 2);

        vm.prank(owner);
        depositPoolInstance.setDuration(2);

        vm.startPrank(bob);
        stETH.approve(address(depositPoolInstance), 0.1 ether);
        depositPoolInstance.deposit(address(stETH), 0.1 ether);

        skip((One_Month * 2) + 2);

        depositPoolInstance.withdraw();
        // two months + 2s rewards for 0.1 ether * 2
        assertEq(depositPoolInstance.userPoints(bob), 15289350 * 2);
        vm.stopPrank();
    }

    function test_SetDurationWorks() public {
        assertEq(depositPoolInstance.duration(), 0);
        vm.prank(owner);
        depositPoolInstance.setDuration(1);
        assertEq(depositPoolInstance.duration(), One_Month);
    }

    function test_EventDeposit() public {
        vm.expectEmit(true, false, false, true);
        emit Deposit(alice, 0.3 ether);
        vm.startPrank(alice);
        rETH.approve(address(depositPoolInstance), 0.3 ether);
        depositPoolInstance.deposit(address(rETH), 0.3 ether);
    }

    // function test_EventWithdrawn() public {
    //     hoax(alice);
    //     depositPoolInstance.deposit{value: 0.1 ether}();

    //     vm.warp(One_Day);

    //     vm.expectEmit(false, false, false, true);
    //     emit Withdrawn(alice, 0.1 ether, One_Day - 1);
    //     hoax(alice);
    //     depositPoolInstance.withdraw();
    // }

    function test_EventDurationSet() public {
        vm.expectEmit(false, false, false, true);
        emit DurationSet(0, One_Month * 3);
        vm.prank(owner);
        depositPoolInstance.setDuration(3);
    }
}
