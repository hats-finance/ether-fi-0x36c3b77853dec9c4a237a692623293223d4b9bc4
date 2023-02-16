// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";
import "lib/forge-std/src/console.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public liquidityPool;
    EETH public eETH;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        liquidityPool = new LiquidityPool(owner);
        eETH = new EETH(address(liquidityPool));
        liquidityPool.setTokenAddress(address(eETH));
        vm.stopPrank();
    }

    function test_DepositLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 2 ether);
        liquidityPool.deposit{value: 1 ether}();
        assertEq(eETH.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 1 ether);
    }

    function test_DepositLiquidityFails() public {
        vm.startPrank(owner);
        vm.expectRevert();
        liquidityPool.deposit{value: 2 ether}();
    }

    function test_WithdrawLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 3 ether);
        liquidityPool.deposit{value: 2 ether}();
        assertEq(alice.balance, 1 ether);
        assertEq(eETH.balanceOf(alice), 2 ether);

        liquidityPool.withdraw(2 ether);
        assertEq(eETH.balanceOf(alice), 0);
        assertEq(alice.balance, 3 ether);
    }

    function test_WithdrawLiquidityPoolFails() public {
        startHoax(alice);
        vm.expectRevert("Not enough eETH");
        liquidityPool.withdraw(2 ether);
    }

    function test_WithdrawFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool(owner);

        startHoax(alice);
        vm.expectRevert();
        liquidityPool.withdraw(2 ether);
    }

    function test_DepositFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool(owner);

        vm.startPrank(alice);
        vm.deal(alice, 3 ether);
        vm.expectRevert();
        liquidityPoolNoToken.deposit{value: 2 ether}();
    }
}
