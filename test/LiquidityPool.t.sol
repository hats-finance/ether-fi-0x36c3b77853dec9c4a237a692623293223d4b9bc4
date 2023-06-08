// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console.sol";

contract LiquidityPoolTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    function setUp() public {
        setUpTests();
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
    }

    function test_StakingManagerLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 2 ether);
        vm.expectRevert("User is not whitelisted");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);
        vm.stopPrank();

        hoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        startHoax(owner);
        stakingManagerInstance.enableWhitelist();
        vm.expectRevert("User is not whitelisted");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, bobProof);
        stakingManagerInstance.disableWhitelist();
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.enableWhitelist();

        startHoax(alice);
        uint256 aliceBalBefore = alice.balance;
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        assertEq(eETHInstance.balanceOf(alice), 1 ether);
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(alice.balance, aliceBalBefore - 2 ether);
    }

    function test_StakingManagerLiquidityFails() public {
        vm.prank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        vm.startPrank(owner);
        vm.expectRevert();
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
    }

    function test_WithdrawLiquidityPoolSuccess() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        assertEq(bob.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);
        assertEq(alice.balance, 0 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        liquidityPoolInstance.withdraw(alice, 2 ether);
        assertEq(eETHInstance.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        liquidityPoolInstance.withdraw(bob, 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        assertEq(bob.balance, 3 ether);
        vm.stopPrank();
    }

    function test_WithdrawLiquidityPoolFails() public {
        vm.deal(address(liquidityPoolInstance), 3 ether);
        startHoax(alice);
        vm.expectRevert("Not enough eETH");
        liquidityPoolInstance.withdraw(alice, 2 ether);
    }

    function test_WithdrawFailsNotInitializedToken() public {
        startHoax(alice);
        vm.expectRevert();
        liquidityPoolInstance.withdraw(alice, 2 ether);
    }

    function test_StakingManagerFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool();

        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        vm.deal(alice, 3 ether);
        vm.expectRevert();
        liquidityPoolNoToken.deposit{value: 2 ether}(alice, aliceProof);
    }

    function test_LiquidityPoolBatchDepositWithBidIds() public {
        vm.deal(alice, 3 ether);
        vm.deal(owner, 4 ether);

        vm.startPrank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.expectRevert("Ownable: caller is not the owner");
        liquidityPoolInstance.batchDepositWithBidIds(1, bidIds, aliceProof);
        vm.stopPrank();

        vm.startPrank(owner);
        bytes32[] memory proof = getWhitelistMerkleProof(9);

        vm.expectRevert("B-NFT holder must deposit 2 ETH per validator");
        liquidityPoolInstance.batchDepositWithBidIds(1, bidIds, proof);

        vm.expectRevert("Not enough balance");
        liquidityPoolInstance.batchDepositWithBidIds{value: 2 ether}(1, bidIds, proof);

        vm.stopPrank();

        vm.deal(address(liquidityPoolInstance), 70 ether);

        vm.startPrank(owner);
        stakingManagerInstance.enableWhitelist();
        uint256[] memory longBidIds = new uint256[](2);
        longBidIds[0] = bidIds[0];
        longBidIds[1] = bidIds[0];
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, longBidIds, proof);

        assertEq(address(liquidityPoolInstance).balance, 70 ether + 2 ether - 32 ether);
        assertEq(address(stakingManagerInstance).balance, 32 ether);
        assertEq(address(owner).balance, 2 ether);
        assertEq(newValidators.length, 1);
        assertEq(newValidators[0], 1);
    }

    function test_WithdrawLiquidityPoolAccrueStakingRewardsWithoutPartialWithdrawal() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        assertEq(bob.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.rebase(2 ether + 4 ether, 4 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        (bool sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(sent, true);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        (sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(sent, true);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        (sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(sent, false);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        vm.stopPrank();
    }
    
    function test_LiquidityPoolBatchRegisterValidators() public {
        vm.deal(owner, 100 ether);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);
        assertEq(bidIds.length, 2);

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(address(liquidityPoolInstance).balance, 60 ether);

        bytes32[] memory proof = getWhitelistMerkleProof(9);
        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
        assertEq(newValidators.length, 2);
        assertEq(address(liquidityPoolInstance).balance, 0 ether);
        assertEq(address(stakingManagerInstance).balance, 64 ether);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](2);

        for (uint256 i = 0; i < newValidators.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                newValidators[i]
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

        bytes32 depositRoot = _getDepositRoot();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

        vm.prank(owner);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0 ether);
        assertEq(TNFTInstance.ownerOf(newValidators[0]), address(liquidityPoolInstance));
        assertEq(TNFTInstance.ownerOf(newValidators[1]), address(liquidityPoolInstance));
        assertEq(BNFTInstance.ownerOf(newValidators[0]), owner);
        assertEq(BNFTInstance.ownerOf(newValidators[1]), owner);
    }

    function test_ProcessNodeExit() public {
        vm.deal(owner, 100 ether);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0);

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);
        vm.stopPrank();

        bytes32[] memory proof = getWhitelistMerkleProof(9);

        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](2);

        for (uint256 i = 0; i < newValidators.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                newValidators[i]
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

        bytes32 depositRoot = _getDepositRoot();

        vm.prank(owner);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

        uint256[] memory slashingPenalties = new uint256[](2);
        slashingPenalties[0] = 0.5 ether;
        slashingPenalties[1] = 0.5 ether;

        vm.prank(owner);
        liquidityPoolInstance.rebase(64 ether - 1 ether, 0 ether);

        vm.expectRevert("validator node is not exited");
        vm.prank(owner);
        managerInstance.fullWithdrawBatch(newValidators);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.sendExitRequests(newValidators);

        vm.prank(owner);
        liquidityPoolInstance.sendExitRequests(newValidators);

        uint32[] memory exitRequestTimestamps = new uint32[](2);
        exitRequestTimestamps[0] = 1681351200; // Thu Apr 13 2023 02:00:00 UTC
        exitRequestTimestamps[1] = 1681075815; // Sun Apr 09 2023 21:30:15 UTC

        vm.warp(1681351200 + 12 * 6);

        address etherfiNode1 = managerInstance.etherfiNodeAddress(newValidators[0]);
        address etherfiNode2 = managerInstance.etherfiNodeAddress(newValidators[1]);

        _transferTo(etherfiNode1, 32 ether - slashingPenalties[0]);
        _transferTo(etherfiNode2, 32 ether - slashingPenalties[1]);

        // Process the node exit via nodeManager
        vm.prank(owner);
        managerInstance.processNodeExit(newValidators, exitRequestTimestamps);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 64 ether - 1 ether);
        assertTrue(managerInstance.isExited(newValidators[0]));
        assertTrue(managerInstance.isExited(newValidators[1]));

        // Delist the node from the liquidity pool
        vm.prank(owner);
        managerInstance.fullWithdrawBatch(newValidators);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 63 ether);
        assertEq(address(liquidityPoolInstance).balance, 60.135937500000000000 ether);
    }

    function test_SettersFailOnZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert("No zero addresses");
        liquidityPoolInstance.setTokenAddress(address(0));
        
        vm.expectRevert("No zero addresses");
        liquidityPoolInstance.setStakingManager(address(0));

        vm.expectRevert("No zero addresses");
        liquidityPoolInstance.setEtherFiNodesManager(address(0));

        vm.stopPrank();
    }

    function test_LiquidStakingAccessControl() public {

        vm.prank(owner);
        liquidityPoolInstance.closeEEthLiquidStaking();

        hoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        vm.prank(owner);
        stakingManagerInstance.enableWhitelist();

        hoax(alice);
        vm.expectRevert("Liquid staking functions are closed");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        vm.prank(owner);
        liquidityPoolInstance.openEEthLiquidStaking();

        hoax(alice);
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        vm.prank(owner);
        liquidityPoolInstance.closeEEthLiquidStaking();
        
        hoax(alice);
        vm.expectRevert("Liquid staking functions are closed");
        liquidityPoolInstance.withdraw(alice, 1 ether);
    }
}
