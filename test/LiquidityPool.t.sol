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
        regulationsManagerInstance.confirmEligibility("Hash_Example");

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
        regulationsManagerInstance.confirmEligibility("Hash_Example");

        vm.startPrank(owner);
        vm.expectRevert();
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
    }

    function test_WithdrawLiquidityPoolSuccess() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
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
        LiquidityPool liquidityPoolNoToken = new LiquidityPool();

        startHoax(alice);
        vm.expectRevert();
        liquidityPoolInstance.withdraw(alice, 2 ether);
    }

    function test_StakingManagerFailsNotInitializedToken() public {
        LiquidityPool liquidityPoolNoToken = new LiquidityPool();

        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        vm.deal(alice, 3 ether);
        vm.expectRevert();
        liquidityPoolNoToken.deposit{value: 2 ether}(alice, aliceProof);
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

        vm.startPrank(owner);
        stakingManagerInstance.enableWhitelist();
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds(1, bidIds);

        assertEq(address(liquidityPoolInstance).balance, 3 ether);
        assertEq(address(stakingManagerInstance).balance, 32 ether);
        assertEq(newValidators.length, 1);
        assertEq(newValidators[0], 1);
    }

    function test_WithdrawLiquidityPoolSlashingPenalties() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        assertEq(bob.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedSlashingPenalty(1 ether);
        assertEq(eETHInstance.balanceOf(alice), 1.5 ether);
        assertEq(eETHInstance.balanceOf(bob), 1.5 ether);

        liquidityPoolInstance.setAccruedSlashingPenalty(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 1 ether);
        assertEq(eETHInstance.balanceOf(bob), 1 ether);
        vm.stopPrank();
    }

    function test_WithdrawLiquidityPoolAccrueStakingRewardsWithoutPartialWithdrawal() public {
        vm.deal(alice, 3 ether);
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(alice.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 0);
        vm.stopPrank();

        vm.deal(bob, 3 ether);
        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        assertEq(bob.balance, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);
        vm.stopPrank();

        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.setAccruedStakingReards(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        assertEq(liquidityPoolInstance.accruedStakingRewards(), 2 ether);
        (bool sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(sent, true);
        assertEq(liquidityPoolInstance.accruedStakingRewards(), 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        (sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(sent, true);
        assertEq(liquidityPoolInstance.accruedStakingRewards(), 0 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        vm.expectRevert("Update the accrued rewards first");
        (sent, ) = address(liquidityPoolInstance).call{value: 1 ether}("");
        assertEq(liquidityPoolInstance.accruedStakingRewards(), 0 ether);
        assertEq(eETHInstance.balanceOf(alice), 3 ether);
        assertEq(eETHInstance.balanceOf(bob), 3 ether);

        vm.stopPrank();
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
        assertEq(bidIds.length, 2);

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 64 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(address(liquidityPoolInstance).balance, 64 ether);

        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds(2, bidIds);
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

        assertFalse(liquidityPoolInstance.validators(newValidators[0]));
        assertFalse(liquidityPoolInstance.validators(newValidators[1]));
        assertEq(liquidityPoolInstance.numValidators(), 0);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

        vm.prank(owner);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);

        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0 ether);
        assertTrue(liquidityPoolInstance.validators(newValidators[0]));
        assertTrue(liquidityPoolInstance.validators(newValidators[1]));
        assertEq(liquidityPoolInstance.numValidators(), 2);
        assertEq(TNFTInstance.ownerOf(newValidators[0]), address(liquidityPoolInstance));
        assertEq(TNFTInstance.ownerOf(newValidators[1]), address(liquidityPoolInstance));
        assertEq(BNFTInstance.ownerOf(newValidators[0]), owner);
        assertEq(BNFTInstance.ownerOf(newValidators[1]), owner);
    }

    function test_ProcessNodeExit() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 64 ether}(bob, bobProof);
        vm.stopPrank();


        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds(2, bidIds);

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

        uint256[] memory slashingPenalties = new uint256[](2);
        slashingPenalties[0] = 0.5 ether;
        slashingPenalties[1] = 0.5 ether;

        vm.prank(owner);
        liquidityPoolInstance.setAccruedSlashingPenalty(1 ether);

        vm.expectRevert("Incorrect Phase");
        vm.prank(owner);
        liquidityPoolInstance.processNodeExit(newValidators, slashingPenalties);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.sendExitRequests(newValidators);

        vm.prank(owner);
        liquidityPoolInstance.sendExitRequests(newValidators);

        address node1 = managerInstance.etherfiNodeAddress(newValidators[0]);
        address node2 = managerInstance.etherfiNodeAddress(newValidators[1]);

        EtherFiNode etherFiNode1 = EtherFiNode(payable(node1));
        EtherFiNode etherFiNode2 = EtherFiNode(payable(node2));


        uint32[] memory exitRequestTimestamps = new uint32[](2);
        exitRequestTimestamps[0] = 1681351200; // Thu Apr 13 2023 02:00:00 UTC
        exitRequestTimestamps[1] = 1681075815; // Sun Apr 09 2023 21:30:15 UTC

        // Process the node exit via nodeManager
        vm.prank(owner);
        managerInstance.processNodeExit(newValidators, exitRequestTimestamps);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        liquidityPoolInstance.processNodeExit(newValidators, slashingPenalties);

        assertEq(liquidityPoolInstance.numValidators(), 2);
        assertTrue(liquidityPoolInstance.validators(newValidators[0]));
        assertTrue(liquidityPoolInstance.validators(newValidators[1]));

        assertEq(liquidityPoolInstance.accruedSlashingPenalties(), 1 ether);
        
        // Delist the node from the liquidity pool
        vm.prank(owner);
        liquidityPoolInstance.processNodeExit(newValidators, slashingPenalties);

        assertEq(liquidityPoolInstance.numValidators(), 0);
        assertFalse(liquidityPoolInstance.validators(newValidators[0]));
        assertFalse(liquidityPoolInstance.validators(newValidators[1]));
        assertEq(liquidityPoolInstance.accruedSlashingPenalties(), 0 ether);
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
}
