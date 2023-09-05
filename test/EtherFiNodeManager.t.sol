// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "../src/EtherFiNode.sol";

contract EtherFiNodesManagerTest is TestSetup {
    address etherFiNode;
    uint256[] bidId;
    EtherFiNode safeInstance;

    function setUp() public {
        setUpTests();

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        managerImplementation.initialize(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TNFTInstance),
            address(BNFTInstance),
            address(protocolRevenueManagerInstance));
        
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, _ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray
        );

        etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);

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
            managerInstance.phase(bidId[0]) == IEtherFiNode.VALIDATOR_PHASE.LIVE
        );

        safeInstance = EtherFiNode(payable(etherFiNode));
    }

    function test_SetStakingRewardsSplit() public {
        vm.expectRevert("Caller is not the admin");
        vm.prank(owner);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 400000);

        vm.expectRevert("Amounts not equal to 1000000");
        vm.prank(alice);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 300000);

        (uint64 treasury, uint64 nodeOperator, uint64 tnft, uint64 bnft) = managerInstance.stakingRewardsSplit();
        assertEq(treasury, 50000);
        assertEq(nodeOperator, 50000);
        assertEq(tnft, 815625);
        assertEq(bnft, 84375);

        vm.prank(alice);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 400000);

        (treasury, nodeOperator, tnft, bnft) = managerInstance.stakingRewardsSplit();
        assertEq(treasury, 100000);
        assertEq(nodeOperator, 100000);
        assertEq(tnft, 400000);
        assertEq(bnft, 400000);
    }

    function test_SetProtocolRewardsSplit() public {
        vm.expectRevert("Caller is not the admin");
        vm.prank(owner);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 400000);

        vm.expectRevert("Amounts not equal to 1000000");
        vm.prank(alice);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 300000);

        (uint64 treasury, uint64 nodeOperator, uint64 tnft, uint64 bnft) = managerInstance.protocolRewardsSplit();
        assertEq(treasury, 250000);
        assertEq(nodeOperator, 250000);
        assertEq(tnft, 453125);
        assertEq(bnft, 46875);

        vm.prank(alice);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 400000);

        (treasury, nodeOperator, tnft, bnft) = managerInstance.protocolRewardsSplit();
        assertEq(treasury, 100000);
        assertEq(nodeOperator, 100000);
        assertEq(tnft, 400000);
        assertEq(bnft, 400000);
    }

    function test_SetNonExitPenaltyPrincipal() public {
        vm.expectRevert("Caller is not the admin");
        vm.prank(owner);
        managerInstance.setNonExitPenaltyPrincipal(2 ether);

        assertEq(managerInstance.nonExitPenaltyPrincipal(), 1 ether);

        vm.prank(alice);
        managerInstance.setNonExitPenaltyPrincipal(2 ether);

        assertEq(managerInstance.nonExitPenaltyPrincipal(), 2 ether);
    }

    function test_SetNonExitPenaltyDailyRate() public {
        vm.expectRevert("Caller is not the admin");
        vm.prank(owner);
        managerInstance.setNonExitPenaltyDailyRate(2 ether);

        assertEq(managerInstance.nonExitPenaltyDailyRate(), 3);

        vm.prank(alice);
        managerInstance.setNonExitPenaltyDailyRate(5);

        assertEq(managerInstance.nonExitPenaltyDailyRate(), 5);
    }

    function test_SetEtherFiNodePhaseRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only staking manager contract function");
        vm.prank(owner);
        managerInstance.setEtherFiNodePhase(bidId[0], IEtherFiNode.VALIDATOR_PHASE.CANCELLED);
    }

    function test_setEtherFiNodeIpfsHashForEncryptedValidatorKeyRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only staking manager contract function");
        vm.prank(owner);
        managerInstance.setEtherFiNodeIpfsHashForEncryptedValidatorKey(bidId[0], "_ipfsHash");
    }

    function test_RegisterEtherFiNodeRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only staking manager contract function");
        vm.prank(owner);
        managerInstance.registerEtherFiNode(bidId[0], etherFiNode);
    }

    function test_RegisterEtherFiNodeRevertsIfAlreadyRegistered() public {
        // Node is registered in setup
        vm.expectRevert("already installed");
        vm.prank(address(stakingManagerInstance));
        managerInstance.registerEtherFiNode(bidId[0], etherFiNode);
    }

    function test_UnregisterEtherFiNodeRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only staking manager contract function");
        vm.prank(owner);
        managerInstance.unregisterEtherFiNode(bidId[0]);
    }

    function test_UnregisterEtherFiNodeRevertsIfAlreadyUnregistered() public {
        vm.prank(address(stakingManagerInstance));
        managerInstance.unregisterEtherFiNode(bidId[0]);

        vm.expectRevert("not installed");
        vm.prank(address(stakingManagerInstance));
        managerInstance.unregisterEtherFiNode(bidId[0]);
    }

    function test_CreateEtherFiNode() public {
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            alice,
            _ipfsHash,
            5
        );

        hoax(alice);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        assertEq(managerInstance.etherfiNodeAddress(bidId[0]), address(0));

        hoax(alice);
        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId);

        address node = managerInstance.etherfiNodeAddress(processedBids[0]);
        assert(node != address(0));
    }

    function test_RegisterEtherFiNode() public {
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            alice,
            _ipfsHash,
            5
        );

        hoax(alice);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        assertEq(managerInstance.etherfiNodeAddress(bidId[0]), address(0));

        hoax(alice);
        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId);

        address node = managerInstance.etherfiNodeAddress(processedBids[0]);
        assert(node != address(0));

    }

    function test_UnregisterEtherFiNode() public {
        address node = managerInstance.etherfiNodeAddress(bidId[0]);
        assert(node != address(0));

        vm.prank(address(stakingManagerInstance));
        managerInstance.unregisterEtherFiNode(bidId[0]);

        node = managerInstance.etherfiNodeAddress(bidId[0]);
        assertEq(node, address(0));
    }

    function test_SendExitRequestWorksCorrectly() public {
        assertEq(managerInstance.isExitRequested(bidId[0]), false);

        hoax(alice);
        vm.expectRevert("You are not the owner of the T-NFT");
        managerInstance.sendExitRequest(bidId[0]);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        managerInstance.sendExitRequest(bidId[0]);

        assertEq(managerInstance.isExitRequested(bidId[0]), true);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Exit request was already sent.");
        managerInstance.sendExitRequest(bidId[0]);

        uint256[] memory ids = new uint256[](1);
        ids[0] = bidId[0];
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Exit request was already sent.");
        managerInstance.batchSendExitRequest(ids);

        address etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);
        uint32 exitRequestTimestamp = IEtherFiNode(etherFiNode).exitRequestTimestamp();

        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 0);

        // 1 day passed
        vm.warp(block.timestamp + (1 + 86400));
        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 0.03 ether);

        vm.warp(block.timestamp + (1 + (86400 + 3600)));
        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 0.0591 ether);

        vm.warp(block.timestamp + (1 + 2 * 86400));
        assertEq(
            IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)),
            0.114707190000000000 ether
        );

        // 10 days passed
        vm.warp(block.timestamp + (1 + 10 * 86400));
        assertEq(
            IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)),
            0.347163722539392386 ether
        );

        // 28 days passed
        vm.warp(block.timestamp + (1 + 28 * 86400));
        assertEq(
            IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)),
            0.721764308786155954 ether
        );

        // 365 days passed
        vm.warp(block.timestamp + (1 + 365 * 86400));
        assertEq(
            IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)),
            1 ether
        );

        // more than 1 year passed
        vm.warp(block.timestamp + (1 + 366 * 86400));
        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 1 ether);

        vm.warp(block.timestamp + (1 + 400 * 86400));
        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 1 ether);

        vm.warp(block.timestamp + (1 + 1000 * 86400));
        assertEq(IEtherFiNode(etherFiNode).getNonExitPenalty(exitRequestTimestamp, uint32(block.timestamp)), 1 ether);
    }

    function test_PausableModifierWorks() public {
        hoax(alice);
        managerInstance.pauseContract();
        
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Pausable: paused");
        managerInstance.sendExitRequest(bidId[0]);

        uint256[] memory ids = new uint256[](1);
        ids[0] = bidId[0];

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Pausable: paused");
        managerInstance.batchSendExitRequest(ids);

        uint32[] memory timeStamps = new uint32[](1);
        ids[0] = block.timestamp;

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.processNodeExit(ids, timeStamps);

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.partialWithdraw(0);

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.partialWithdrawBatch(ids);

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.partialWithdrawBatchGroupByOperator(alice, ids);

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.fullWithdraw(0);

        hoax(alice);
        vm.expectRevert("Pausable: paused");
        managerInstance.fullWithdrawBatch(ids);

    }
}
