// WithdrawRequestNFTTest.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/console2.sol";
import "./TestSetup.sol";

contract WithdrawRequestNFTTest is TestSetup {
    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    function setUp() public {
        setUpTests();
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
    }

    function test_WithdrawRequestNftInitializedCorrectly() public {
        assertEq(address(withdrawRequestNFTInstance.liquidityPool()), address(liquidityPoolInstance));
        assertEq(address(withdrawRequestNFTInstance.eETH()), address(eETHInstance));
    }

    function test_RequestWithdraw() public {
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.balanceOf(address(bob)), 10 ether);

        uint96 amountOfEEth = 1 ether;
        // uint96 shareOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId = withdrawRequestNFTInstance.getNextRequestId() - 1;
        WithdrawRequestNFT.WithdrawRequest memory request = withdrawRequestNFTInstance.getRequest(requestId);

        assertEq(request.amountOfEEth, 1 ether, "Amount of eEth should match");
        assertEq(request.shareOfEEth, 1 ether, "Share of eEth should match");
        assertTrue(request.isValid, "Request should be valid");
    }

    function test_requestIdIncrements() public {
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        uint96 amountOfEEth = 1 ether;
        uint96 shareOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId1 = withdrawRequestNFTInstance.getNextRequestId() - 1;
        assertEq(requestId1, 1, "Request id should be 1");

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId2 = withdrawRequestNFTInstance.getNextRequestId() - 1;
        assertEq(requestId2, 2, "Request id should be 2");
    }

    function test_finalizeRequests() public {
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        uint96 amountOfEEth = 1 ether;
        uint96 shareOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId = withdrawRequestNFTInstance.getNextRequestId() - 1;
        bool earlyRequestIsFinalized = withdrawRequestNFTInstance.requestIsFinalized(requestId);
        assertFalse(earlyRequestIsFinalized, "Request should not be Finalized");

        vm.prank(alice);
        withdrawRequestNFTInstance.finalizeRequests(requestId);

        WithdrawRequestNFT.WithdrawRequest memory request = withdrawRequestNFTInstance.getRequest(requestId);
        assertEq(request.amountOfEEth, 1 ether, "Amount of eEth should match");

        bool requestIsFinalized = withdrawRequestNFTInstance.requestIsFinalized(requestId);
        assertTrue(requestIsFinalized, "Request should be finalized");
    }

    function test_requestWithdraw() public {
                startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        uint96 amountOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId = withdrawRequestNFTInstance.getNextRequestId() - 1;

        bool requestIsFinalized = withdrawRequestNFTInstance.requestIsFinalized(requestId);
        assertFalse(requestIsFinalized, "Request should not be finalized");

        WithdrawRequestNFT.WithdrawRequest memory request = withdrawRequestNFTInstance.getRequest(requestId);
        assertEq(request.amountOfEEth, 1 ether, "Amount of eEth should match");
        assertEq(request.shareOfEEth, 1 ether, "Share of eEth should match");
        assertTrue(request.isValid, "Request should be valid");
    }

    function testInvalidClaimWithdraw() public {
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        uint96 amountOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId = withdrawRequestNFTInstance.getNextRequestId() - 1;
        bool requestIsFinalized = withdrawRequestNFTInstance.requestIsFinalized(requestId);
        assertFalse(requestIsFinalized, "Request should not be finalized");

        vm.expectRevert("Request is not finalized");
        vm.prank(address(liquidityPoolInstance));
        withdrawRequestNFTInstance.claimWithdraw(requestId);
    }

    function test_ValidClaimWithdraw() public {
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        uint96 amountOfEEth = 1 ether;

        vm.prank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), amountOfEEth);

        vm.prank(bob);
        liquidityPoolInstance.requestWithdraw(bob, amountOfEEth);

        uint256 requestId = withdrawRequestNFTInstance.getNextRequestId() - 1;

        assertEq(withdrawRequestNFTInstance.balanceOf(bob), 1, "Bobs balance should be 1");

        vm.prank(alice);
        withdrawRequestNFTInstance.finalizeRequests(requestId);

        vm.prank(bob);
        withdrawRequestNFTInstance.claimWithdraw(requestId);

        // bobs balance of eth should be 9?
        assertEq(address(bob).balance, 9 ether, "Bobs balance should be 9 ether");
    }

    function testUpdateLiquidityPool() public {
        address newLiquidityPool = address(0x456);
        vm.prank(alice);
        withdrawRequestNFTInstance.updateLiquidityPool(newLiquidityPool);
        assertEq(address(withdrawRequestNFTInstance.liquidityPool()), newLiquidityPool, "Liquidity pool should be updated");
    }

    function testUpdateEEth() public {
        address newEEth = address(0x789);
        vm.prank(alice);
        withdrawRequestNFTInstance.updateEEth(newEEth);
        assertEq(address(withdrawRequestNFTInstance.eETH()), newEEth, "eETH should be updated");
    }

    function testUpdateAdmin() public {
        address newAdmin = address(0xabc);
        vm.prank(owner);
        withdrawRequestNFTInstance.updateAdmin(newAdmin);
        assertEq(address(withdrawRequestNFTInstance.admin()), newAdmin, "Admin should be updated");
    }
}