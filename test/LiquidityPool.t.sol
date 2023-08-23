// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract LiquidityPoolTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public henryProof;
    bytes32[] public elvisProof;
    bytes32[] public chadProof;
    bytes32[] public firstIndexPlayerProof;
    bytes32[] public beforeFirstIndexPlayerProof;
    bytes32[] public lastIndexPlayerProof;
    uint256[] public processedBids;
    uint256[] public validatorArray;
    uint256[] public bidIds;
    bytes[] public sig;

    function setUp() public {
        setUpTests();
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);

        sig = new bytes[](1);
        sig[0] = hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df";

        vm.deal(alice, 100 ether);
        vm.startPrank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            10000
        );
        bidIds = auctionInstance.createBid{value: 1 ether}(
            10,
            0.1 ether
        );
        vm.stopPrank();
    }

    function test_DepositOrWithdrawOfZeroFails() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        stakingManagerInstance.disableWhitelist();
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        vm.expectRevert(LiquidityPool.InvalidAmount.selector);
        liquidityPoolInstance.deposit{value: 0 ether}(alice, aliceProof);

        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        vm.expectRevert(LiquidityPool.InvalidAmount.selector);
        liquidityPoolInstance.requestWithdraw(alice, 0);

        vm.stopPrank();
    }

    function test_StakingManagerLiquidityPool() public {
        vm.startPrank(alice);
        vm.deal(alice, 2 ether);
        vm.expectRevert("User is not eligible to participate");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);
        vm.stopPrank();

        hoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        startHoax(alice);
        stakingManagerInstance.enableWhitelist();
        vm.expectRevert("User is not whitelisted");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, bobProof);
        stakingManagerInstance.disableWhitelist();
        vm.stopPrank();

        vm.prank(alice);
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
        eETHInstance.approve(address(liquidityPoolInstance), 2 ether);
        uint256 aliceReqId = liquidityPoolInstance.requestWithdraw(alice, 2 ether);
        withdrawRequestNFTInstance.finalizeRequests(aliceReqId);
        withdrawRequestNFTInstance.claimWithdraw(aliceReqId);
        assertEq(eETHInstance.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 2 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        eETHInstance.approve(address(liquidityPoolInstance), 2 ether);
        uint256 bobReqId = liquidityPoolInstance.requestWithdraw(bob, 2 ether);
        vm.stopPrank();

        vm.prank(alice);
        withdrawRequestNFTInstance.finalizeRequests(bobReqId);

        vm.startPrank(bob);
        withdrawRequestNFTInstance.claimWithdraw(bobReqId);
        assertEq(eETHInstance.balanceOf(bob), 0);
        assertEq(bob.balance, 3 ether);
        vm.stopPrank();
    }

    function test_WithdrawLiquidityPoolFails() public {
        vm.deal(bob, 100 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 100 ether}(bob, bobProof);        
        vm.stopPrank();

        startHoax(alice);
        eETHInstance.approve(address(liquidityPoolInstance), 2 ether);
        vm.expectRevert("Not enough eETH");
        liquidityPoolInstance.requestWithdraw(alice, 2 ether);
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

    // function test_LiquidityPoolBatchDepositWithBidIds() public {
    //     vm.deal(alice, 4 ether);
    //     vm.deal(owner, 3 ether);

    //     vm.startPrank(owner);
    //     nodeOperatorManagerInstance.registerNodeOperator(
    //         _ipfsHash,
    //         5
    //     );
    //     uint256[] memory bidIds = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
    //     auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

    //     vm.expectRevert("Caller is not the admin");
    //     liquidityPoolInstance.batchDepositWithBidIds(1, bidIds, aliceProof);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     bytes32[] memory proof = getWhitelistMerkleProof(9);

    //     vm.expectRevert("B-NFT holder must deposit 2 ETH per validator");
    //     liquidityPoolInstance.batchDepositWithBidIds(1, bidIds, proof);

    //     vm.expectRevert("Not enough balance");
    //     liquidityPoolInstance.batchDepositWithBidIds{value: 2 ether}(1, bidIds, proof);
    //     vm.stopPrank();

    //     vm.deal(bob, 70 ether);
    //     vm.startPrank(bob);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     liquidityPoolInstance.deposit{value: 70 ether}(bob, bobProof);        
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     stakingManagerInstance.enableWhitelist();
    //     uint256[] memory longBidIds = new uint256[](2);
    //     longBidIds[0] = bidIds[0];
    //     longBidIds[1] = bidIds[0];
    //     uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, longBidIds, proof);

    //     assertEq(address(liquidityPoolInstance).balance, 70 ether + 2 ether - 32 ether);
    //     assertEq(address(stakingManagerInstance).balance, 32 ether);
    //     assertEq(address(alice).balance, 2 ether);
    //     assertEq(newValidators.length, 1);
    //     assertEq(newValidators[0], 11);
    // }

    function test_selfdestruct() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(alice.balance, 1 ether);
        assertEq(address(liquidityPoolInstance).balance, 2 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);

        _transferTo(address(attacker), 1 ether);
        attacker.attack();

        // While the 'selfdestruct' attack can change the LP contract's balance,
        // it does not affect the critical logics for determining ETH amount per share
        // so, the balance of Alice remains the same as 2 ether.
        assertEq(alice.balance, 1 ether);
        assertEq(address(liquidityPoolInstance).balance, 3 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
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
        vm.prank(owner);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        vm.prank(address(membershipManagerInstance));
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
    }
    
    // function test_LiquidityPoolBatchRegisterValidators() public {
    //     vm.deal(owner, 100 ether);

    //     hoax(alice);
    //     uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);
    //     assertEq(bidIds.length, 2);

    //     startHoax(bob);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
    //     vm.stopPrank();

    //     assertEq(address(liquidityPoolInstance).balance, 60 ether);

    //     bytes32[] memory proof = getWhitelistMerkleProof(9);
    //     vm.prank(alice);
    //     uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
    //     assertEq(newValidators.length, 2);
    //     assertEq(address(liquidityPoolInstance).balance, 0 ether);
    //     assertEq(address(stakingManagerInstance).balance, 64 ether);
    //     assertEq(liquidityPoolInstance.numPendingDeposits(), 2);

    //     IStakingManager.DepositData[]
    //         memory depositDataArray = new IStakingManager.DepositData[](2);

    //     for (uint256 i = 0; i < newValidators.length; i++) {
    //         address etherFiNode = managerInstance.etherfiNodeAddress(
    //             newValidators[i]
    //         );
    //         bytes32 root = depGen.generateDepositRoot(
    //             hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             managerInstance.generateWithdrawalCredentials(etherFiNode),
    //             32 ether
    //         );
    //         depositDataArray[i] = IStakingManager.DepositData({
    //             publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             depositDataRoot: root,
    //             ipfsHashForEncryptedValidatorKey: "test_ipfs"
    //         });
    //     }

    //     bytes32 depositRoot = _getDepositRoot();

    //     vm.expectRevert("Caller is not the admin");
    //     vm.prank(owner);
    //     liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

    //     vm.prank(alice);
    //     liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

    //     assertEq(liquidityPoolInstance.numPendingDeposits(), 0);
    //     assertEq(address(stakingManagerInstance).balance, 0 ether);
    //     assertEq(address(liquidityPoolInstance).balance, 0 ether);
    //     assertEq(TNFTInstance.ownerOf(newValidators[0]), address(liquidityPoolInstance));
    //     assertEq(TNFTInstance.ownerOf(newValidators[1]), address(liquidityPoolInstance));
    //     assertEq(BNFTInstance.ownerOf(newValidators[0]), owner);
    //     assertEq(BNFTInstance.ownerOf(newValidators[1]), owner);
    // }
    
    // function test_batchCancelDeposit() public {
    //     vm.deal(owner, 100 ether);

    //     hoax(alice);
    //     uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);
    //     assertEq(bidIds.length, 2);

    //     assertEq(liquidityPoolInstance.totalValueOutOfLp(), 0);
    //     assertEq(liquidityPoolInstance.totalValueInLp(), 0);

    //     startHoax(bob);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
    //     vm.stopPrank();

    //     assertEq(address(liquidityPoolInstance).balance, 60 ether);
    //     assertEq(liquidityPoolInstance.totalValueOutOfLp(), 0);
    //     assertEq(liquidityPoolInstance.totalValueInLp(), 60 ether);

    //     uint256 aliceBalance = address(alice).balance;
    //     bytes32[] memory proof = getWhitelistMerkleProof(9);
    //     vm.prank(alice);
    //     uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);

    //     assertEq(newValidators.length, 2);
    //     assertEq(address(alice).balance, aliceBalance - 2 * 2 ether);
    //     assertEq(address(liquidityPoolInstance).balance, 0 ether);
    //     assertEq(address(stakingManagerInstance).balance, 64 ether);
    //     assertEq(liquidityPoolInstance.numPendingDeposits(), 2);
    //     assertEq(liquidityPoolInstance.totalValueOutOfLp(), 60 ether);
    //     assertEq(liquidityPoolInstance.totalValueInLp(), 0);

    //     vm.prank(alice);
    //     liquidityPoolInstance.batchCancelDeposit(newValidators);

    //     assertEq(liquidityPoolInstance.numPendingDeposits(), 0);
    //     assertEq(liquidityPoolInstance.totalValueOutOfLp(), 0);
    //     assertEq(liquidityPoolInstance.totalValueInLp(), 60 ether);
    //     assertEq(address(alice).balance, aliceBalance);
    //     assertEq(address(stakingManagerInstance).balance, 0 ether);
    //     assertEq(address(liquidityPoolInstance).balance, 60 ether);
    // }

    // function test_ProcessNodeExit() public {
    //     vm.deal(owner, 100 ether);

    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 0);

    //     hoax(alice);
    //     uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

    //     startHoax(bob);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);
    //     vm.stopPrank();

    //     bytes32[] memory proof = getWhitelistMerkleProof(9);

    //     vm.warp(1681075815 - 35 * 24 * 3600);   // Sun March ...
    //     vm.prank(alice);
    //     uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

    //     IStakingManager.DepositData[]
    //         memory depositDataArray = new IStakingManager.DepositData[](2);

    //     for (uint256 i = 0; i < newValidators.length; i++) {
    //         address etherFiNode = managerInstance.etherfiNodeAddress(
    //             newValidators[i]
    //         );
    //         bytes32 root = depGen.generateDepositRoot(
    //             hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             managerInstance.generateWithdrawalCredentials(etherFiNode),
    //             32 ether
    //         );
    //         depositDataArray[i] = IStakingManager.DepositData({
    //             publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             depositDataRoot: root,
    //             ipfsHashForEncryptedValidatorKey: "test_ipfs"
    //         });
    //     }

    //     bytes32 depositRoot = _getDepositRoot();

    //     vm.prank(alice);
    //     liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

    //     uint256[] memory slashingPenalties = new uint256[](2);
    //     slashingPenalties[0] = 0.5 ether;
    //     slashingPenalties[1] = 0.5 ether;

    //     vm.prank(address(membershipManagerInstance));
    //     liquidityPoolInstance.rebase(64 ether - 1 ether, 0 ether);

    //     vm.expectRevert("validator node is not exited");
    //     vm.prank(owner);
    //     managerInstance.fullWithdrawBatch(newValidators);

    //     vm.expectRevert("Caller is not the admin");
    //     vm.prank(owner);
    //     liquidityPoolInstance.sendExitRequests(newValidators);

    //     vm.warp(1681075815 - 7 * 24 * 3600);   // Sun Apr 02 2023 21:30:15 UTC
    //     vm.prank(alice);
    //     liquidityPoolInstance.sendExitRequests(newValidators);

    //     uint32[] memory exitRequestTimestamps = new uint32[](2);
    //     exitRequestTimestamps[0] = 1681351200; // Thu Apr 13 2023 02:00:00 UTC
    //     exitRequestTimestamps[1] = 1681075815; // Sun Apr 09 2023 21:30:15 UTC

    //     vm.warp(1681351200 + 12 * 6);

    //     address etherfiNode1 = managerInstance.etherfiNodeAddress(newValidators[0]);
    //     address etherfiNode2 = managerInstance.etherfiNodeAddress(newValidators[1]);

    //     _transferTo(etherfiNode1, 32 ether - slashingPenalties[0]);
    //     _transferTo(etherfiNode2, 32 ether - slashingPenalties[1]);

    //     // Process the node exit via nodeManager
    //     vm.prank(alice);
    //     managerInstance.processNodeExit(newValidators, exitRequestTimestamps);

    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 64 ether - 1 ether);
    //     assertTrue(managerInstance.isExited(newValidators[0]));
    //     assertTrue(managerInstance.isExited(newValidators[1]));

    //     // Delist the node from the liquidity pool
    //     vm.prank(alice);
    //     managerInstance.fullWithdrawBatch(newValidators);

    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 63 ether);
    //     assertEq(address(liquidityPoolInstance).balance, 60.045312500000000000 ether);
    // }

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

        startHoax(alice);
        liquidityPoolInstance.closeEEthLiquidStaking();

        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        stakingManagerInstance.enableWhitelist();

        vm.expectRevert("Liquid staking functions are closed");
        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        liquidityPoolInstance.openEEthLiquidStaking();

        liquidityPoolInstance.deposit{value: 1 ether}(alice, aliceProof);

        liquidityPoolInstance.closeEEthLiquidStaking();
    
        vm.stopPrank();
    }

    function test_fallback() public {
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0 ether);

        vm.deal(bob, 100 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 100 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 100 ether);
        vm.prank(address(membershipManagerInstance));
        liquidityPoolInstance.rebase(103 ether, 100 ether);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 103 ether);

        vm.deal(alice, 3 ether);
        vm.prank(alice);
        (bool sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(address(liquidityPoolInstance).balance, 100 ether + 1 ether);
        assertEq(sent, true);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 103 ether);
    }

    // function test_rebase_withdraw_flow() public {
    //     uint256[] memory validatorIds = launch_validator();

    //     uint256[] memory tvls = new uint256[](4);

    //     for (uint256 i = 0; i < validatorIds.length; i++) {
    //         uint256 beaconBalance = 16 ether * (i + 1) + 1 ether;
    //         (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury)
    //             = managerInstance.calculateTVL(validatorIds[i], beaconBalance, true, true, true, true);
    //         tvls[0] += toNodeOperator;
    //         tvls[1] += toTnft;
    //         tvls[2] += toBnft;
    //         tvls[3] += toTreasury;
    //     }

    //     assertEq(address(liquidityPoolInstance).balance, 0 ether);
    //     assertEq(eETHInstance.totalSupply(), 60 ether);
    //     assertEq(eETHInstance.balanceOf(bob), 60 ether);

    //     uint256 eEthTVL = tvls[1];

    //     vm.startPrank(address(membershipManagerInstance));
    //     liquidityPoolInstance.rebase(eEthTVL, 0 ether);
    //     vm.stopPrank();

    //     assertEq(address(liquidityPoolInstance).balance, 0 ether);
    //     assertEq(eETHInstance.totalSupply(), eEthTVL);
    //     assertEq(eETHInstance.balanceOf(bob), eEthTVL);

    //     // After a long period of time (after the auction fee vesting period completes)
    //     skip(6 * 7 * 4 days);

    //     uint32[] memory exitRequestTimestamps = new uint32[](2);
    //     exitRequestTimestamps[0] = uint32(block.timestamp);
    //     exitRequestTimestamps[1] = uint32(block.timestamp);

    //     address etherfiNode1 = managerInstance.etherfiNodeAddress(validatorIds[0]);
    //     address etherfiNode2 = managerInstance.etherfiNodeAddress(validatorIds[1]);

    //     _transferTo(etherfiNode1, 17 ether);
    //     _transferTo(etherfiNode2, 33 ether);

    //     // Process the node exit via nodeManager
    //     vm.prank(alice);
    //     managerInstance.processNodeExit(validatorIds, exitRequestTimestamps);
    //     managerInstance.fullWithdrawBatch(validatorIds);

    //     assertEq(address(liquidityPoolInstance).balance, eEthTVL);
    //     assertEq(eETHInstance.totalSupply(), eEthTVL);
    //     assertEq(eETHInstance.balanceOf(bob), eEthTVL);

    //     vm.startPrank(bob);
    //     eETHInstance.approve(address(liquidityPoolInstance), eEthTVL);
    //     uint256 bobRequestId = liquidityPoolInstance.requestWithdraw(bob, eEthTVL);
    //     vm.stopPrank();

    //     vm.prank(alice);
    //     withdrawRequestNFTInstance.finalizeRequests(bobRequestId);

    //     vm.prank(bob);
    //     withdrawRequestNFTInstance.claimWithdraw(bobRequestId);

    //     assertEq(address(liquidityPoolInstance).balance, 0);
    //     assertEq(eETHInstance.totalSupply(), 0);
    //     assertEq(eETHInstance.balanceOf(bob), 0);
    // }

    // function launch_validator() internal returns (uint256[] memory) {
    //     vm.deal(owner, 100 ether);       
    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 0);

    //     hoax(alice);
    //     uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

    //     startHoax(bob);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);
    //     vm.stopPrank();

    //     bytes32[] memory proof = getWhitelistMerkleProof(9);

    //     vm.prank(alice);
    //     uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
    //     assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

    //     IStakingManager.DepositData[]
    //         memory depositDataArray = new IStakingManager.DepositData[](2);

    //     for (uint256 i = 0; i < newValidators.length; i++) {
    //         address etherFiNode = managerInstance.etherfiNodeAddress(
    //             newValidators[i]
    //         );
    //         bytes32 root = depGen.generateDepositRoot(
    //             hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             managerInstance.generateWithdrawalCredentials(etherFiNode),
    //             32 ether
    //         );
    //         depositDataArray[i] = IStakingManager.DepositData({
    //             publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
    //             signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
    //             depositDataRoot: root,
    //             ipfsHashForEncryptedValidatorKey: "test_ipfs"
    //         });
    //     }

    //     bytes32 depositRoot = _getDepositRoot();
    //     vm.prank(alice);
    //     liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);
    
    //     return newValidators;
    // }

    function test_RegisterAsBnftHolder() public {

        //Move past one week
        vm.warp(804650);

        //Let Alice sign up as a BNFT holder
        vm.prank(alice);
        liquidityPoolInstance.registerAsBnftHolder(alice);

        (uint128 timestamp, uint128 numOfActiveHolders) = liquidityPoolInstance.holdersUpdate();

        assertEq(timestamp, 804650);
        assertEq(numOfActiveHolders, 0);

        //Move another week ahead to reset the active holders
        vm.warp(1609250);

        //Let Greg sign up as a BNFT holder
        vm.prank(alice);
        liquidityPoolInstance.registerAsBnftHolder(greg);

        (timestamp, numOfActiveHolders) = liquidityPoolInstance.holdersUpdate();

        assertEq(timestamp, 1609250);
        assertEq(numOfActiveHolders, 1);
    }

    function test_DutyForWeek() public {

        //Sets up the list of BNFT holders
        setUpBnftHolders();

        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);

        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 120 ether}(address(alice), aliceProof);

        //Move forward in time to make sure dutyForWeek runs with an arbitrary timestamp
        vm.warp(13431561615);

        (uint256 firstIndex, uint128 lastIndex, uint128 lastIndexNumOfValidators) = liquidityPoolInstance.dutyForWeek();
        assertEq(firstIndex, 7);
        assertEq(lastIndex, 7);
        assertEq(lastIndexNumOfValidators, 4);

        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 630 ether}(address(alice), aliceProof);
        
        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        (firstIndex, lastIndex, lastIndexNumOfValidators) = liquidityPoolInstance.dutyForWeek();

        assertEq(firstIndex, 7);
        assertEq(lastIndex, 5);
        assertEq(lastIndexNumOfValidators, 1);

    }
    
    function test_DepositAsBnftHolderSimple() public {

        bobProof = merkle.getProof(whiteListedAddresses, 4);
        henryProof = merkle.getProof(whiteListedAddresses, 11);
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        chadProof = merkle.getProof(whiteListedAddresses, 5);
        
        //Sets up the list of BNFT holders
        setUpBnftHolders();

        vm.startPrank(alice);

        //Move to a random time in the future
        vm.warp(13431561615);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);

        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 120 ether}(address(alice), aliceProof);

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        liquidityPoolInstance.dutyForWeek();

        vm.stopPrank();
        vm.prank(bob);

        //Making sure a user cannot deposit using another user's index
        vm.expectRevert("Incorrect Caller");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, bobProof, 7);

        vm.prank(bob);

        //Making sure a user cannot deposit if they are not assigned
        vm.expectRevert("Not assigned");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, bobProof, 2);

        vm.prank(henry);

        //Making sure if a user is assigned they send in the correct amount (This will be updated 
        //as we will allow users to specify how many validator they want to spin up)
        vm.expectRevert("B-NFT holder must deposit 2 ETH per validator");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 6 ether}(bidIds, henryProof, 7);

        //Move way more in the future
        vm.warp(33431561615);
        vm.prank(alice);

        //This triggers the number of active holders to be updated to include the previous bnft holders
        //However, Chad will not be included in this weeks duty
        liquidityPoolInstance.registerAsBnftHolder(chad);

        vm.startPrank(alice);
        
        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 300 ether}(address(alice), aliceProof);

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        (uint256 firstIndex, uint128 lastIndex, uint128 numForLastIndex) = liquidityPoolInstance.dutyForWeek();

        assertEq(firstIndex, 5);
        assertEq(lastIndex, 0);
        assertEq(numForLastIndex, 2);

        //With the current timestamps and data, the following is true
        //First Index = 5 
        //Last Index = 0
        //Num Validators For Last = 2

        //Alice deposits and her index is 0 (the last index), allowing her to deposit for 2 validators
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 4 ether}(bidIds, aliceProof, 0);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.numPendingDeposits(), 2);

        vm.prank(henry);

        //Henry deposits and his index is 7, allowing him to deposit
        uint256[] memory validators = liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, henryProof, 7);
        assertEq(liquidityPoolInstance.numPendingDeposits(), 6);
        assertEq(validators[0], 3);
        assertEq(validators[1], 4);
        assertEq(validators[2], 5);
        assertEq(validators[3], 6);

        vm.prank(chad);

        //Chad attempts to deposit, however, due to his index being 8 and not being apart of this weeks duty, he is not assigned
        vm.expectRevert("Not assigned");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, chadProof, 8);
    }

    function test_DepositAsBnftHolderWithLargeSet() public {

        firstIndexPlayerProof = merkle.getProof(whiteListedAddresses, 12);
        beforeFirstIndexPlayerProof = merkle.getProof(whiteListedAddresses, 13);
        lastIndexPlayerProof = merkle.getProof(whiteListedAddresses, 14);

        //Add 1000 people to the BNFT holder array
        for (uint i = 1; i <= 1000; i++) {
            address actor = vm.addr(i);
            bnftHoldersArray.push(actor);
            vm.deal(actor, 1000 ether);
            vm.prank(alice);
            liquidityPoolInstance.registerAsBnftHolder(actor);
        }

        vm.startPrank(alice);

        //Move to a random period in time
        vm.warp(1684181656753);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);

        vm.deal(alice, 100000 ether);
        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 77000 ether}(address(alice), aliceProof);
        vm.stopPrank();

        //Call duty for the week, and in this example, the data is:
        //First Index = 682
        //Last Index = 515
        //Num Validators For Last = 1
        (uint256 firstIndex, uint128 lastIndex, uint128 numOfValidatorsForLastIndex) = liquidityPoolInstance.dutyForWeek();

        vm.startPrank(alice);
        nodeOperatorManagerInstance.addToWhitelist(liquidityPoolInstance.bnftHolders(firstIndex));
        nodeOperatorManagerInstance.addToWhitelist(liquidityPoolInstance.bnftHolders(firstIndex - 1));
        nodeOperatorManagerInstance.addToWhitelist(liquidityPoolInstance.bnftHolders(lastIndex));
        vm.stopPrank();

        //Give the user in the first index position funds
        vm.deal(liquidityPoolInstance.bnftHolders(firstIndex), 10 ether);
        vm.startPrank(liquidityPoolInstance.bnftHolders(firstIndex));

        //Allow the user in the first index position to deposit 
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, firstIndexPlayerProof, firstIndex);
        assertEq(liquidityPoolInstance.numPendingDeposits(), 4);

        vm.stopPrank();

        vm.startPrank(liquidityPoolInstance.bnftHolders(firstIndex - 1));

        //User who is one short of the assigned first index attempts to deposit but fails
        vm.expectRevert("Not assigned");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, beforeFirstIndexPlayerProof, firstIndex - 1);
        vm.stopPrank();

        vm.deal(liquidityPoolInstance.bnftHolders(lastIndex), 10 ether);
        vm.startPrank(liquidityPoolInstance.bnftHolders(lastIndex));

        //User who is last in the selection deposits with the correct amount of funds
        uint256 amount = 2 ether * numOfValidatorsForLastIndex;
        liquidityPoolInstance.batchDepositAsBnftHolder{value: amount}(bidIds, lastIndexPlayerProof, lastIndex);
        assertEq(liquidityPoolInstance.numPendingDeposits(), 4 + numOfValidatorsForLastIndex);
        vm.stopPrank();
    }

    function test_DepositWhenMaxBnftValidatorChanges() public {

        henryProof = merkle.getProof(whiteListedAddresses, 11);
        elvisProof = merkle.getProof(whiteListedAddresses, 7);
        chadProof = merkle.getProof(whiteListedAddresses, 5);
        
        //Sets up the list of BNFT holders
        setUpBnftHolders();

        vm.startPrank(alice);

        //Move to a random time in the future
        vm.warp(13431561615);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);

        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 120 ether}(address(alice), aliceProof);

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        liquidityPoolInstance.dutyForWeek();

        vm.stopPrank();
        
        vm.startPrank(alice);

        //Set the max number of validators per holder to 6
        liquidityPoolInstance.setMaxBnftSlotSize(6);

        vm.stopPrank();

        //Move way more in the future
        vm.warp(33431561615);
        vm.prank(alice);

        //This triggers the number of active holders to be updated to include the previous bnft holders
        //However, Chad will not be included in this weeks duty
        liquidityPoolInstance.registerAsBnftHolder(chad);

        vm.startPrank(alice);
        
        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 370 ether}(address(alice), aliceProof);

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        liquidityPoolInstance.dutyForWeek();

        //With the current timestamps and data, the following is true
        //First Index = 5 
        //Last Index = 7
        //Num Validators For Last = 4
        vm.stopPrank();

        vm.startPrank(henry);
        //Henry deposits and his index is 7, meaning he is last and deposits 4 * 2 ether
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, henryProof, 7);
        assertEq(liquidityPoolInstance.numPendingDeposits(), 4);

        vm.stopPrank();

        vm.startPrank(elvis);
        //Elvis deposits and his index is 6, allowing him to deposit
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 12 ether}(bidIds, elvisProof, 6);
        assertEq(liquidityPoolInstance.numPendingDeposits(), 10);
        vm.stopPrank();

        vm.startPrank(chad);
        //Chad attempts to deposit, however, due to his index being 8 and not being apart of this weeks duty, he is not assigned
        vm.expectRevert("Not assigned");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, chadProof, 8);
        vm.stopPrank();
    }

    function test_DeRegisterBnftHolder() public {
        setUpBnftHolders();

        assertEq(liquidityPoolInstance.bnftHolders(3), owner);
        assertEq(liquidityPoolInstance.bnftHolders(7), henry);
        assertEq(liquidityPoolInstance.bnftHolders(2), bob);

        vm.prank(alice);
        liquidityPoolInstance.deRegisterBnftHolder(3);

        assertEq(liquidityPoolInstance.bnftHolders(3), henry);

        vm.prank(bob);
        liquidityPoolInstance.deRegisterBnftHolder(2);

        assertEq(liquidityPoolInstance.bnftHolders(2), elvis);
    }

    function test_DeRegisterBnftHolderIfIncorrectCaller() public {
        setUpBnftHolders();

        vm.prank(bob);
        vm.expectRevert("Incorrect Caller");
        liquidityPoolInstance.deRegisterBnftHolder(3);
    }

    function test_DepositWhenUserDeRegisters() public {

        henryProof = merkle.getProof(whiteListedAddresses, 11);
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        
        //Sets up the list of BNFT holders
        setUpBnftHolders();

        vm.startPrank(alice);

        //Move to a random time in the future
        vm.warp(1731561615);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);
        
        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 630 ether}(address(alice), aliceProof);

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        liquidityPoolInstance.dutyForWeek();

        vm.stopPrank();

        //With the current timestamps and data, the following is true
        //First Index = 4
        //Last Index = 1
        //Num Validators For Last = 1

        vm.startPrank(alice);
        //Alice deposits and her index is 0 (the last index), allowing her to deposit for 2 validators
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, aliceProof, 0);
        vm.stopPrank();

        vm.startPrank(owner);
        //Owner de registers themselves
        liquidityPoolInstance.deRegisterBnftHolder(3);
        vm.stopPrank();

        //Can look in the logs that these numbers get returned, we cant test it without manually calculating numbers
        liquidityPoolInstance.dutyForWeek();

        //With the current timestamps and data, the following is true
        //First Index = 2
        //Last Index = 0
        //Num Validators For Last = 1

        vm.startPrank(greg);
        //Greg attempts to deposit, however, due to his index being 1 after the swap he is not assigned
        vm.expectRevert("Not assigned");
        liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, henryProof, 1);
        vm.stopPrank();
    }

    function test_UpdateSchedulingPeriod() public {
        assertEq(liquidityPoolInstance.schedulingPeriodInSeconds(), 604800);

        vm.prank(alice);
        liquidityPoolInstance.setSchedulingPeriodInSeconds(100000);

        assertEq(liquidityPoolInstance.schedulingPeriodInSeconds(), 100000);
    }

    function test_UpdateSchedulingPeriodFailsIfNotAdmin() public {
        vm.prank(bob);
        vm.expectRevert("Caller is not the admin");
        liquidityPoolInstance.setSchedulingPeriodInSeconds(100000);
    }

    function test_DepositFromBNFTHolder() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.startPrank(alice);
        liquidityPoolInstance.registerAsBnftHolder(alice);
        liquidityPoolInstance.registerAsBnftHolder(greg);

        vm.deal(alice, 100000 ether);
        vm.deal(greg, 100000 ether);

        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        //Set the max number of validators per holder to 4
        liquidityPoolInstance.setMaxBnftSlotSize(4);

        //Alice deposits funds into the LP to allow for validators to be spun and the calculations can work in dutyForWeek
        liquidityPoolInstance.deposit{value: 120 ether}(address(alice), aliceProof);
        vm.stopPrank();

        //Move forward in time to make sure dutyForWeek runs with an arbitrary timestamp
        vm.warp(12431561615);

        liquidityPoolInstance.dutyForWeek();

        startHoax(alice);
        bidIds = auctionInstance.createBid{value: 1 ether}(
            10,
            0.1 ether
        );
        vm.stopPrank();
        
        startHoax(alice);
        processedBids = liquidityPoolInstance.batchDepositAsBnftHolder{value: 8 ether}(bidIds, aliceProof, 0);

        assertEq(stakingManagerInstance.bidIdToStaker(11), alice);
        assertEq(stakingManagerInstance.bidIdToStaker(12), alice);
        assertEq(stakingManagerInstance.bidIdToStaker(13), alice);
        assertEq(stakingManagerInstance.bidIdToStaker(14), alice);
    }

    function test_RegisterAsBNFTHolder() public {
        
        test_DepositFromBNFTHolder();

        assertEq(processedBids[0], 11);
        assertEq(processedBids[1], 12);
        assertEq(processedBids[2], 13);
        assertEq(processedBids[3], 14);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            1 ether
        );
        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        depositDataArray[0] = depositData;

        validatorArray = new uint256[](1);
        validatorArray[0] = processedBids[0];

        assertEq(BNFTInstance.balanceOf(alice), 0);
        assertEq(TNFTInstance.balanceOf(address(liquidityPoolInstance)), 0);

        sig = new bytes[](1);
        sig[0] = hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df";

        liquidityPoolInstance.batchRegisterAsBnftHolder(zeroRoot, validatorArray, depositDataArray, sig);

        assertEq(liquidityPoolInstance.numPendingDeposits(), 3);
        assertEq(BNFTInstance.balanceOf(alice), 1);
        assertEq(TNFTInstance.balanceOf(address(liquidityPoolInstance)), 1);
    }

    function setUpBnftHolders() internal {
        vm.startPrank(alice);
        liquidityPoolInstance.registerAsBnftHolder(alice);
        liquidityPoolInstance.registerAsBnftHolder(greg);
        liquidityPoolInstance.registerAsBnftHolder(bob);
        liquidityPoolInstance.registerAsBnftHolder(owner);
        liquidityPoolInstance.registerAsBnftHolder(shonee);
        liquidityPoolInstance.registerAsBnftHolder(dan);
        liquidityPoolInstance.registerAsBnftHolder(elvis);
        liquidityPoolInstance.registerAsBnftHolder(henry);
        vm.stopPrank();

        vm.deal(alice, 100000 ether);
        vm.deal(greg, 100000 ether);
        vm.deal(bob, 100000 ether);
        vm.deal(owner, 100000 ether);
        vm.deal(shonee, 100000 ether);
        vm.deal(dan, 100000 ether);
        vm.deal(elvis, 100000 ether);
        vm.deal(henry, 100000 ether);
        vm.deal(chad, 100000 ether);
    }
}
