// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console.sol";

contract LiquidityPoolTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_StakingManagerLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 2 ether);
        liquidityPoolInstance.deposit{value: 1 ether}(alice);
        assertEq(eETHInstance.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 1 ether);
    }

    function test_StakingManagerLiquidityFails() public {
        vm.startPrank(owner);
        vm.expectRevert();
        liquidityPoolInstance.deposit{value: 2 ether}(alice);
    }

    function test_WithdrawLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 3 ether);
        liquidityPoolInstance.deposit{value: 2 ether}(alice);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);

        liquidityPoolInstance.withdraw(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 0);
        assertEq(alice.balance, 3 ether);
    }

    function test_WithdrawLiquidityPoolFails() public {
        startHoax(alice);
        vm.expectRevert("Not enough eETH");
        liquidityPoolInstance.withdraw(2 ether);
    }

    function test_WithdrawFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool();

        startHoax(alice);
        vm.expectRevert();
        liquidityPoolInstance.withdraw(2 ether);
    }

    function test_StakingManagerFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool();

        vm.startPrank(alice);
        vm.deal(alice, 3 ether);
        vm.expectRevert();
        liquidityPoolNoToken.deposit{value: 2 ether}(alice);
    }

    function test_SetEeTHAddress() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.setTokenAddress(address(eETHInstance));

        // address set in setup
        assertEq(liquidityPoolInstance.eETH(), address(eETHInstance));
    }

    function test_SetScoreManagerAddress() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.setScoreManagerAddress(address(scoreManagerInstance));

        // address set in setup
        assertEq(liquidityPoolInstance.scoreManagerAddress(), address(scoreManagerInstance));
    }

    function test_SetStakingManagerAddress() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.setStakingManagerAddress(address(stakingManagerInstance));

        // address set in setup
        assertEq(liquidityPoolInstance.stakingManagerAddress(), address(stakingManagerInstance));
    }

    function test_SetEtherFiNodesManagerAddress() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.setEtherFiNodesManagerAddress(address(managerInstance));

        // address set in setup
        assertEq(liquidityPoolInstance.etherFiNodesManagerAddress(), address(managerInstance));
    }
}
