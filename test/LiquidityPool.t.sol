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

    function test_LiquidityPoolBatchRegisterValidators() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

        hoax(bob);
        liquidityPoolInstance.deposit{value: 64 ether}(bob);

        vm.prank(owner);
        uint256[] memory processedBidIds = liquidityPoolInstance.batchDepositWithBidIds{value: 64 ether}(bidIds);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](10);

        for (uint256 i = 0; i < processedBidIds.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                processedBidIds[i]
            );
            bytes32 root = depGen.generateDepositRoot(
                hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                managerInstance.generateWithdrawalCredentials(etherFiNode),
                32 ether
            );
            depositDataArray[i] = IStakingManager.DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        }

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.batchRegisterValidators(processedBidIds, depositDataArray);
    }

}
