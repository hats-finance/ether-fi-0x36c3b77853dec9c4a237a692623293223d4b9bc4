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
        liquidityPoolInstance.deposit{value: 1 ether}(alice);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(alice.balance, 0 ether);
    }

    function test_StakingManagerLiquidityFails() public {
        vm.startPrank(owner);
        vm.expectRevert();
        liquidityPoolInstance.deposit{value: 2 ether}(alice);
    }

    function test_WithdrawLiquidityPoolSuccess() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 2 ether}(bob);
        assertEq(bob.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        liquidityPoolInstance.withdraw(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 0);
        assertEq(alice.balance, 3 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        liquidityPoolInstance.withdraw(2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        assertEq(bob.balance, 3 ether);
        vm.stopPrank();
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

    function test_LiquidityPoolBatchDepositWithBidIds() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.batchDepositWithBidIds(1, bidIds);

        vm.expectRevert("Not enough balance");
        vm.prank(owner);
        liquidityPoolInstance.batchDepositWithBidIds(1, bidIds);

        vm.deal(address(liquidityPoolInstance), 35 ether);
        assertEq(address(liquidityPoolInstance).balance, 35 ether);

        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds(1, bidIds);

        assertEq(address(liquidityPoolInstance).balance, 3 ether);
        assertEq(address(stakingManagerInstance).balance, 32 ether);
        assertEq(newValidators.length, 1);
        assertEq(newValidators[0], 1);
    }

}
