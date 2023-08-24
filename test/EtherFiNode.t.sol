// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "../src/EtherFiNode.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

contract EtherFiNodeTest is TestSetup {

    // from EtherFiNodesManager.sol
    uint256 TreasuryRewardSplit = 50_000;
    uint256 NodeOperatorRewardSplit = 50_000;
    uint256 TNFTRewardSplit = 815_625;
    uint256 BNFTRewardSplit = 84_375;
    uint256 RewardSplitDivisor = 1_000_000;

    uint256[] bidId;
    EtherFiNode safeInstance;

    function setUp() public {
       
        setUpTests();

        assertTrue(node.phase() == IEtherFiNode.VALIDATOR_PHASE.NOT_INITIALIZED);

        vm.expectRevert("already initialized");
        vm.prank(owner);
        node.initialize(address(managerInstance));

        bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 1);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof2,
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        assertTrue(
            managerInstance.phase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
        });

        depositDataArray[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(zeroRoot, bidId, depositDataArray);
        vm.stopPrank();

        assertTrue(
            managerInstance.phase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );

        safeInstance = EtherFiNode(payable(etherFiNode));

        assertEq(address(etherFiNode).balance, 0 ether);
        assertEq(
            auctionInstance.accumulatedRevenue(),
            0.1 ether
        );
    }

    function test_SetExitRequestTimestampFailsOnIncorrectCaller() public {
        vm.expectRevert("Only EtherFiNodeManager Contract");
        vm.prank(alice);
        safeInstance.setExitRequestTimestamp();
    }

    function test_SetPhaseRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only EtherFiNodeManager Contract");
        vm.prank(owner);
        safeInstance.setPhase(IEtherFiNode.VALIDATOR_PHASE.EXITED);

    }

    function test_SetIpfsHashForEncryptedValidatorKeyRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only EtherFiNodeManager Contract");
        vm.prank(owner);
        safeInstance.setIpfsHashForEncryptedValidatorKey("_ipfsHash");

    }

    function test_SetExitRequestTimestampRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only EtherFiNodeManager Contract");
        vm.prank(owner);
        safeInstance.setExitRequestTimestamp();

    }

    function test_EtherFiNodeMultipleSafesWorkCorrectly() public {

        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);
        bytes32[] memory danProof = merkle.getProof(whiteListedAddresses, 6);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceIPFSHash,
            5
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceIPFSHash,
            5
        );

        hoax(alice);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.4 ether}(
            1,
            0.4 ether
        );

        hoax(chad);
        uint256[] memory bidId2 = auctionInstance.createBid{value: 0.3 ether}(
            1,
            0.3 ether
        );

        hoax(bob);
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId1[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            bobProof,
            bob
        );

        hoax(dan);
        bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            danProof,
            dan
        );

        {
            address staker_2 = stakingManagerInstance.bidIdToStaker(bidId1[0]);
            address staker_3 = stakingManagerInstance.bidIdToStaker(bidId2[0]);
            assertEq(staker_2, bob);
            assertEq(staker_3, dan);
        }

        address etherFiNode = managerInstance.etherfiNodeAddress(bidId1[0]);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        depositDataArray[0] = depositData;

        startHoax(bob);
        stakingManagerInstance.batchRegisterValidators(zeroRoot, bidId1, depositDataArray);
        vm.stopPrank();

        assertEq(address(managerInstance.etherfiNodeAddress(bidId1[0])).balance, 0);

        etherFiNode = managerInstance.etherfiNodeAddress(bidId2[0]);

        IStakingManager.DepositData[]
            memory depositDataArray2 = new IStakingManager.DepositData[](1);

        root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        
        depositDataArray2[0] = depositData;

        startHoax(dan);
        stakingManagerInstance.batchRegisterValidators(zeroRoot, bidId2, depositDataArray2);
        vm.stopPrank();

        assertEq(address(managerInstance.etherfiNodeAddress(bidId2[0])).balance, 0);
    }

    function test_markExitedWorksCorrectly() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherFiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);

        vm.expectRevert("Only EtherFiNodeManager Contract");
        IEtherFiNode(etherFiNode).markExited(1);

        vm.expectRevert("Caller is not the admin");
        vm.prank(owner);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);

        hoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() > 0);

        hoax(alice);
        vm.expectRevert("Invalid phase transition");
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
    }

    function test_markExitedWorksCorrectlyWhenBeingSlashed() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherFiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);

        hoax(alice);
        managerInstance.markBeingSlashed(validatorIds);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.BEING_SLASHED);
        hoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() > 0);
    }

    function test_evict() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherFiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);
        assertEq(address(etherFiNode).balance, 0.00 ether); // node no longer receives auction revenue

        uint256 nodeOperatorBalance = address(nodeOperator).balance;

        vm.prank(alice);
        managerInstance.processNodeEvict(validatorIds);

        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EVICTED);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() > 0);
        assertEq(address(etherFiNode).balance, 0);
        assertEq(address(nodeOperator).balance, nodeOperatorBalance);
    }

    function test_partialWithdraw() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;
        address etherfiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        // Transfer the T-NFT to 'dan'
        hoax(staker);
        TNFTInstance.transferFrom(staker, dan, bidId[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        // Simulate the rewards distribution from the beacon chain
        vm.deal(etherfiNode, address(etherfiNode).balance + 1 ether);

        // Withdraw the {staking, protocol} rewards
        // - bid amount = 0 ether (Auction revenue no longer distributed to nodes)
        //   - 50 % ether is vested for the stakers
        //   - 50 % ether is shared across all validators
        //     - 25 % to treasury, 25% to node operator, the rest to the stakers
        // - staking rewards amount = 1 ether
        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(
            address(nodeOperator).balance,
            nodeOperatorBalance + (1 ether * 5) / 100 + (0.0 ether * 50 * 25) / (100 * 100)
        );
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + (1 ether * 5 ) / 100 + (0.0 ether * 50 * 25) / (100 * 100)
        );
        assertEq(address(dan).balance, danBalance + 0.815625000000000000 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 0.084375000000000000 ether);

        vm.deal(etherfiNode, 8.0 ether);
        vm.expectRevert(
            "etherfi node contract's balance is above 8 ETH. You should exit the node."
        );
        managerInstance.partialWithdraw(bidId[0]);
    }

    function test_partialWithdrawFails() public {
        address etherfiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        vm.deal(etherfiNode, 4 ether);

        vm.expectRevert(
            "Caller is not the admin"
        );
        vm.prank(owner);
        managerInstance.markBeingSlashed(bidId);

        hoax(alice);
        managerInstance.markBeingSlashed(bidId);
        vm.expectRevert(
            "you can skim the rewards only when the node is LIVE or FULLY_WITHDRAWN."
        );
        managerInstance.partialWithdraw(bidId[0]);
    }

    function test_markBeingSlashedFails() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;

        hoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);

        hoax(alice);
        vm.expectRevert("Invalid phase transition");
        managerInstance.markBeingSlashed(bidId);
    }

    function test_markBeingSlashedWorks() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherFiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(alice);
        managerInstance.markBeingSlashed(bidId);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.BEING_SLASHED);
    }

    function test_partialWithdrawAfterExitRequest() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;
        address etherfiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        // Simulate the rewards distribution from the beacon chain
        vm.deal(etherfiNode, address(etherfiNode).balance + 1 ether);

        // Transfer the T-NFT to 'dan'
        hoax(staker);
        TNFTInstance.transferFrom(staker, dan, bidId[0]);

        // Send Exit Request and wait for 14 days to pass
        hoax(dan);
        managerInstance.sendExitRequest(bidId[0]);
        vm.warp(block.timestamp + (1 + 14 * 86400));

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        uint256 nodeOperatorBalance2 = address(nodeOperator).balance;

        // node operator gets nothing because took longer than 14 days
        assertEq(address(nodeOperator).balance, nodeOperatorBalance);
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + 0.05 ether + 0.05 ether // 5% rewards + 5% rewards that would have gone to node operator
        );

        // dan should recieve the T-NFT share
        uint256 danExpectedStakingRewards = 1 ether * TNFTRewardSplit / RewardSplitDivisor;
        assertEq(address(dan).balance, danBalance + danExpectedStakingRewards);

        uint256 bnftExpectedStakingRewards = 1 ether * BNFTRewardSplit / RewardSplitDivisor;
        assertEq(address(staker).balance, bnftStakerBalance + bnftExpectedStakingRewards);

        // No additional rewards if call 'partialWithdraw' again
        uint256 withdrawnOperatorBalance = address(nodeOperator).balance;
        uint256 withdrawnTreasuryBalance = address(treasuryInstance).balance;
        uint256 withdrawnDanBalance = dan.balance;
        uint256 withdrawnBNFTBalance = address(staker).balance;
        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(address(nodeOperator).balance, withdrawnOperatorBalance);
        assertEq(address(treasuryInstance).balance, withdrawnTreasuryBalance);
        assertEq(address(dan).balance, withdrawnDanBalance);
        assertEq(address(staker).balance, withdrawnBNFTBalance);
    }

    function test_getFullWithdrawalPayoutsFails() public {

        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        address etherfiNode = managerInstance.etherfiNodeAddress(
            validatorIds[0]
        );

        vm.deal(etherfiNode, 16 ether);
        vm.expectRevert("validator node is not exited");
        managerInstance.fullWithdraw(validatorIds[0]);
    }

    function test_processNodeDistributeProtocolRevenueCorrectly() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;

        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 stakerBalance = address(staker).balance;

        startHoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        vm.stopPrank();

        // no auction rewards anymore
        assertEq(address(nodeOperator).balance, nodeOperatorBalance);
        assertEq(address(treasuryInstance).balance, treasuryBalance);
        assertEq(address(staker).balance, stakerBalance);
    }


    function test_getFullWithdrawalPayoutsWorksCorrectly1() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        startHoax(alice);
        assertEq(managerInstance.numberOfValidators(), 1);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertEq(managerInstance.numberOfValidators(), 0);
        vm.stopPrank();

        // 1. balance > 32 ether
        vm.deal(etherfiNode, 33 ether);
        assertEq(address(etherfiNode).balance, 33 ether);

        uint256 stakingRewards = 1 ether;
        (
            uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
        ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, stakingRewards * NodeOperatorRewardSplit / RewardSplitDivisor);
        assertEq(toTreasury, stakingRewards * TreasuryRewardSplit / RewardSplitDivisor);
        assertEq(toTnft, 30 ether + (stakingRewards * TNFTRewardSplit / RewardSplitDivisor));
        assertEq(toBnft, 2 ether + (stakingRewards * BNFTRewardSplit / RewardSplitDivisor));

        // 2. balance > 31.5 ether
        vm.deal(etherfiNode, 31.75 ether);
        assertEq(address(etherfiNode).balance, 31.75 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 30 ether);
        assertEq(toBnft, 1.75 ether);

        // 3. balance > 26 ether
        vm.deal(etherfiNode, 28.5 ether);
        assertEq(address(etherfiNode).balance, 28.5 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 27 ether);
        assertEq(toBnft, 1.5 ether);

        // 4. balance > 25.5 ether
        vm.deal(etherfiNode, 25.75 ether);
        assertEq(address(etherfiNode).balance, 25.75 ether);
        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 24.5 ether);
        assertEq(toBnft, 1.25 ether);

        // 5. balance > 16 ether
        vm.deal(etherfiNode, 18.5 ether);
        assertEq(address(etherfiNode).balance, 18.5 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 17.5 ether);
        assertEq(toBnft, 1 ether);

        // 6. balance < 16 ether
        vm.deal(etherfiNode, 16 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 15 ether);
        assertEq(toBnft, 1 ether);

        // 7. balance < 8 ether
        vm.deal(etherfiNode, 8 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 7.5 ether);
        assertEq(toBnft, 0.5 ether);

        // 8. balance < 4 ether
        vm.deal(etherfiNode, 4 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 3.75 ether);
        assertEq(toBnft, 0.25 ether);

        // 9. balance == 0 ether
        vm.deal(etherfiNode, 0 ether);

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 0 ether);
        assertEq(toBnft, 0 ether);
    }

    function test_partialWithdrawAfterExitFails() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;

        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        // 8. balance < 4 ether
        vm.deal(etherfiNode, 4 ether);

        startHoax(alice);
        assertEq(managerInstance.numberOfValidators(), 1);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertEq(managerInstance.numberOfValidators(), 0);
        vm.stopPrank();

        // Transfer the T-NFT to 'dan'
        hoax(staker);
        TNFTInstance.transferFrom(staker, dan, validatorIds[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        hoax(owner);
        vm.expectRevert("you can skim the rewards only when the node is LIVE or FULLY_WITHDRAWN.");
        managerInstance.partialWithdraw(validatorIds[0]);
    }

    function test_getFullWithdrawalPayoutsAuditFix3() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        startHoax(alice);
        assertEq(managerInstance.numberOfValidators(), 1);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertEq(managerInstance.numberOfValidators(), 0);
        vm.stopPrank();

        uint256 stakingRewards = 0.04 ether;
        vm.deal(etherfiNode, 32 ether + stakingRewards);

        assertEq(address(etherfiNode).balance, 32 ether + stakingRewards);

        {
            (uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
            ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);

            assertEq(toNodeOperator, stakingRewards * NodeOperatorRewardSplit / RewardSplitDivisor);
            assertEq(toTnft, 30 ether + stakingRewards * TNFTRewardSplit / RewardSplitDivisor);
            assertEq(toBnft, 2 ether + stakingRewards * BNFTRewardSplit / RewardSplitDivisor);
            assertEq(toTreasury, stakingRewards * TreasuryRewardSplit / RewardSplitDivisor);
        }

        skip(6 * 7 * 4 days);

        // auction rewards no longer vest so should be the same as above
        {
            (uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
            ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);

            assertEq(toNodeOperator, stakingRewards * NodeOperatorRewardSplit / RewardSplitDivisor);
            assertEq(toTnft, 30 ether + stakingRewards * TNFTRewardSplit / RewardSplitDivisor);
            assertEq(toBnft, 2 ether + stakingRewards * BNFTRewardSplit / RewardSplitDivisor);
            assertEq(toTreasury, stakingRewards * TreasuryRewardSplit / RewardSplitDivisor);
        }
    }

    function test_getFullWithdrawalPayoutsAuditFix2() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        startHoax(alice);
        assertEq(managerInstance.numberOfValidators(), 1);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        assertEq(managerInstance.numberOfValidators(), 0);
        vm.stopPrank();

        //uint256 stakingRewards = 0.949 ether;
        vm.deal(etherfiNode, 31.949 ether);
        assertEq(
            address(etherfiNode).balance,
            31.949000000000000000 ether
        ); 


        skip(6 * 7 * 4 days);

        // auction rewards no longer vest so should be the same as above
        {
            (uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
            ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);

            assertEq(toNodeOperator, 0);
            assertEq(toTnft, 30 ether);
            assertEq(toBnft, 1.949000000000000000 ether);
            assertEq(toTreasury, 0);
        }
    }


    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly1()
        public
    {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp) + 86400;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 1 day passed
        vm.warp(block.timestamp + 86400);
        startHoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);

        // simulate staking rewards
        uint256 stakingRewards = 1 ether;
        vm.deal(etherfiNode, 32 ether + stakingRewards);

        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(nonExitPenalty, 0.03 ether);
        assertEq(toNodeOperator, nonExitPenalty + (stakingRewards * NodeOperatorRewardSplit / RewardSplitDivisor));
        assertEq(toTreasury, stakingRewards * TreasuryRewardSplit / RewardSplitDivisor);
        assertEq(toTnft, 30 ether + (stakingRewards * TNFTRewardSplit / RewardSplitDivisor));
        assertEq(toBnft, 2 ether - nonExitPenalty + (stakingRewards * BNFTRewardSplit / RewardSplitDivisor));
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly2()
        public
    {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp) + (1 + 7 * 86400);
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 7 days passed
        vm.warp(block.timestamp + (1 + 7 * 86400));
        startHoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);

        // simulate staking rewards
        uint256 stakingRewards = 1 ether;
        vm.deal(etherfiNode, 32 ether + stakingRewards);

        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, nonExitPenalty + (stakingRewards * NodeOperatorRewardSplit / RewardSplitDivisor));
        assertEq(toTreasury, stakingRewards * TreasuryRewardSplit / RewardSplitDivisor);
        assertEq(toTnft, 30 ether + (stakingRewards * TNFTRewardSplit / RewardSplitDivisor));
        assertEq(toBnft, 2 ether - nonExitPenalty + (stakingRewards * BNFTRewardSplit / RewardSplitDivisor));
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly4()
        public
    {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp) + 28 * 86400;
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 28 days passed
        // When (appliedPenalty <= 0.2 ether)
        vm.warp(block.timestamp + 28 * 86400);
        startHoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);

        // see EtherFiNode.sol:calculateTVL()
        // principle calculation is decreased because balance < 16 ether. See EtherFiNode.sol:calculatePrincipals()
        // this is min(nonExitPenalty, BNFTPrinciple)
        uint256 expectedAppliedPenalty = 625 * 4 ether / 10_000;

        // the node got slashed seriously
        vm.deal(etherfiNode, 4 ether);
        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(nonExitPenalty, 0.573804794831376551 ether);

        assertEq(toNodeOperator, 0.2 ether); // incentive for nodeOperator from NonExitPenalty caps at 0.2 ether
        assertEq(toTreasury, expectedAppliedPenalty - 0.2 ether); // treasury gets excess penalty if node operator delays too long
        assertEq(toTnft, 3.750000000000000000 ether);
        assertEq(toBnft, 0); // BNFT has been fully penalized for not exiting
    }

    function test_markExitedFails() public {
        uint256[] memory validatorIds = new uint256[](1);
        uint32[] memory exitTimestamps = new uint32[](2);
        startHoax(alice);
        vm.expectRevert("Check params");
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly3() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp) + (1 + 28 * 86400);
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 28 days passed
        // When (appliedPenalty > 0.2 ether)
        vm.warp(block.timestamp + (1 + 28 * 86400));
        startHoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);
        assertGe(nonExitPenalty, 0.5 ether);

        // Treasury gets the excess penalty reward after the node operator hits the 0.2 eth cap
        // Treasury also gets the base reward of the node operator since its over 14 days
        uint256 baseTreasuryPayout = (1 ether * TreasuryRewardSplit / RewardSplitDivisor);
        uint256 baseNodeOperatorPayout = (1 ether * NodeOperatorRewardSplit / RewardSplitDivisor);
        uint256 expectedTreasuryPayout = baseTreasuryPayout + baseNodeOperatorPayout + (nonExitPenalty - 0.2 ether);

        uint256 stakingRewards = 1 ether;
        vm.deal(etherfiNode, 32 ether + stakingRewards);
        (
            uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
        ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.2 ether);
        assertEq(toTreasury, expectedTreasuryPayout);
        assertEq(toTnft, 30 ether + (stakingRewards * TNFTRewardSplit / RewardSplitDivisor));
        assertEq(toBnft, 2 ether - nonExitPenalty + (stakingRewards * BNFTRewardSplit / RewardSplitDivisor));
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly5() public {

        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp) + (1 + 28 * 86400);
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        hoax(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 2 * 28 days passed
        // When (appliedPenalty > 0.2 ether)
        vm.warp(block.timestamp + (1 + 2 * 28 * 86400));
        hoax(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);


        uint256 stakingRewards = 1 ether;
        vm.deal(etherfiNode, 32 ether + stakingRewards);

        // Treasury gets the excess penalty reward after the node operator hits the 0.2 eth cap
        // Treasury also gets the base reward of the node operator since its over 14 days
        uint256 baseTreasuryPayout = (1 ether * TreasuryRewardSplit / RewardSplitDivisor);
        uint256 baseNodeOperatorPayout = (1 ether * NodeOperatorRewardSplit / RewardSplitDivisor);
        uint256 expectedTreasuryPayout = baseTreasuryPayout + baseNodeOperatorPayout + (nonExitPenalty - 0.2 ether);

        (
            uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
        ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.2 ether);
        assertEq(toTreasury, expectedTreasuryPayout);
        assertEq(toTnft, 30 ether + (stakingRewards *TNFTRewardSplit / RewardSplitDivisor));
        assertEq(toBnft, 2 ether - nonExitPenalty + (stakingRewards * BNFTRewardSplit / RewardSplitDivisor));
    }

    function test_sendEthToEtherFiNodeContractSucceeds() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorIds[0]);

        vm.deal(owner, 10 ether);
        vm.prank(owner);
        uint256 nodeBalance = address(etherfiNode).balance;
        (bool sent, ) = address(etherfiNode).call{value: 5 ether}("");
        require(sent, "Failed to send eth");
        assertEq(address(etherfiNode).balance, nodeBalance + 5 ether);
    }

    function test_ExitRequestAfterExitFails() public {
        uint256[] memory validatorIds = new uint256[](1);
        uint32[] memory exitTimestamps = new uint32[](1);

        validatorIds[0] = bidId[0];

        vm.prank(alice);
        managerInstance.processNodeExit(validatorIds, exitTimestamps);

        vm.prank(TNFTInstance.ownerOf(validatorIds[0]));
        exitTimestamps[0] = uint32(block.timestamp);

        // T-NFT holder sends the exit request after the node is marked EXITED
        vm.expectRevert("validator node is not live");
        managerInstance.sendExitRequest(validatorIds[0]);
    }

    function test_ExitTimestampBeforeExitRequestLeadsToZeroNonExitPenalty() public {
        uint256[] memory validatorIds = new uint256[](1);
        uint32[] memory exitTimestamps = new uint32[](1);

        validatorIds[0] = bidId[0];

        vm.prank(TNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // the node actually exited a second before the exit request from the T-NFT holder
        vm.prank(alice);
        exitTimestamps[0] = uint32(block.timestamp) - 1;
        managerInstance.processNodeExit(validatorIds, exitTimestamps);

        uint256 nonExitPenalty = managerInstance.getNonExitPenalty(bidId[0]);
        assertEq(nonExitPenalty, 0 ether);
    }

    function test_ImplementationContract() public {
        assertEq(safeInstance.implementation(), address(node));
    }

    function test_trackingTVL() public {
        uint256 validatorId = bidId[0];
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorId);

        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = (0, 0, 0, 0);

        // (Validator 'active_not_slashed', Accrued rewards in CL = 1 ether)
        {
            uint256 beaconBalance = 32 ether + 1 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0.05 ether);
            assertEq(toTreasury, 0.05 ether);
            assertEq(toTnft, 30.815625000000000000 ether);
            assertEq(toBnft, 2.084375000000000000 ether);
        }

        // (Validator 'active_not_slashed', Accrued rewards in CL = 0)
        {
            uint256 beaconBalance = 32 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0 ether);
            assertEq(toTreasury, 0 ether);
            assertEq(toTnft, 30 ether);
            assertEq(toBnft, 2 ether);
        }

        // (Validator 'active_slashed', slashing penalty in CL = 0.5 ether)
        // - slashing penalty [0, 0.5 ether] is paid by the B-NFT holder
        {
            uint256 beaconBalance = 31.5 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0 ether);
            assertEq(toTreasury, 0 ether);
            assertEq(toTnft, 30 ether);
            assertEq(toBnft, 1.5 ether);
        }

        // (Validator 'active_slashed', slashing penalty in CL = 1 ether)
        // - 0.5 ether of B-NFT holder is used as the insurance claim
        // - While T-NFT receives 29.5 ether, the insurance will convert the loss 0.5 ether (manually)
        {
            uint256 beaconBalance = 31 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0 ether);
            assertEq(toTreasury, 0 ether);
            assertEq(toTnft, 29.5 ether);
            assertEq(toBnft, 1.5 ether);
        }

        {
            uint256 beaconBalance = 30 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0 ether);
            assertEq(toTreasury, 0 ether);
            assertEq(toTnft, 28.5 ether);
            assertEq(toBnft, 1.5 ether);
        }


        // The worst-case, 32 ether is all slashed!
        {
            uint256 beaconBalance = 0 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0 ether);
            assertEq(toTreasury, 0 ether);
            assertEq(toTnft, 0 ether);
            assertEq(toBnft, 0 ether);
        }
    }

    function test_trackingTVL2() public {
        uint256 validatorId = bidId[0];       
        uint256[] memory tvls = new uint256[](4);  // (operator, tnft, bnft, treasury)
        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = (0, 0, 0, 0);

        // Check the staking rewards when we have 1 ether accrued
        {
            uint256 beaconBalance = 32 ether + 1 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, 0.05 ether);
            assertEq(toTreasury, 0.05 ether);
            assertEq(toTnft, 30.815625000000000000 ether);
            assertEq(toBnft, 2.084375000000000000 ether);
            tvls[0] += toNodeOperator;
            tvls[1] += toTnft;
            tvls[2] += toBnft;
            tvls[3] += toTreasury;

            assertEq(beaconBalance, toNodeOperator + toTnft + toBnft + toTreasury);
        }

        // Confirm the total TVL
        {
            uint256 beaconBalance = 32 ether + 1 ether;

            (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance.calculateTVL(validatorId, beaconBalance);
            assertEq(toNodeOperator, tvls[0]);
            assertEq(toTreasury, tvls[3]);
            assertEq(toTnft, tvls[1]);
            assertEq(toBnft, tvls[2]);
        }

        // Confirm that after exiting the validator node from the beacon network,
        // if we trigger the full withdrawal, the same amount is transferred to {stakers, operator, treasury}
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorId);

        uint256[] memory validatorIds = new uint256[](1);
        uint32[] memory exitRequestTimestamps = new uint32[](1);
        validatorIds[0] = validatorId;
        exitRequestTimestamps[0] = uint32(block.timestamp);

        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;

        // Transfer the T-NFT to 'dan' (Just for testing scenario)
        vm.prank(staker);
        TNFTInstance.transferFrom(staker, dan, bidId[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 bnftStakerBalance = address(staker).balance;
        uint256 tNftStakerBalance = address(dan).balance;

        // Simulate the withdrawal from Beacon Network to Execution Layer
        _transferTo(etherfiNode, 32 ether + 1 ether);

        // After a long period of time (after the auction fee vesting period completes)
        skip(6 * 7 * 4 days);

        vm.prank(alice);
        managerInstance.processNodeExit(validatorIds, exitRequestTimestamps); // Marked as EXITED
        managerInstance.fullWithdrawBatch(validatorIds); // Full Withdrawal!

        assertEq(address(nodeOperator).balance, nodeOperatorBalance + tvls[0]);
        assertEq(address(dan).balance, tNftStakerBalance + tvls[1]);
        assertEq(address(staker).balance, bnftStakerBalance + tvls[2]);
        assertEq(address(treasuryInstance).balance, treasuryBalance + tvls[3]);
    }

    function test_withdrawFundsFailsWhenReceiverConsumedTooMuchGas() public {
        uint256 validatorId = bidId[0];
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorId);
        vm.deal(address(etherfiNode), 3 ether); // need to give node some eth because it no longer has auction revenue

        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;
        
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 noAttackerBalance = address(noAttacker).balance;
        uint256 revertAttackerBalance = address(revertAttacker).balance;
        uint256 gasDrainAttackerBalance = address(gasDrainAttacker).balance;

        vm.startPrank(address(managerInstance));
        IEtherFiNode(etherfiNode).withdrawFunds(
            address(treasuryInstance), 0,
            address(revertAttacker), 1,
            address(noAttacker), 1,
            address(gasDrainAttacker), 1
        );
        vm.stopPrank();

        assertEq(address(revertAttacker).balance, revertAttackerBalance);
        assertEq(address(noAttacker).balance, noAttackerBalance + 1);
        assertEq(address(gasDrainAttacker).balance, gasDrainAttackerBalance);
        assertEq(address(treasuryInstance).balance, treasuryBalance + 2);
    }

}
