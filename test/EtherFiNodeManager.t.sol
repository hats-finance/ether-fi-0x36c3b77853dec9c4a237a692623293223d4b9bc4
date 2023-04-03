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

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);

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

        // stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        // assertTrue(
        //     managerInstance.phase(bidId[0]) ==
        //         IEtherFiNode.VALIDATOR_PHASE.LIVE
        // );

        safeInstance = EtherFiNode(payable(etherFiNode));
    }

    function test_SetStakingRewardsSplit() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 400000);

        vm.expectRevert("Amounts not equal to 1000000");
        vm.prank(owner);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 300000);

        (uint64 treasury, uint64 nodeOperator, uint64 tnft, uint64 bnft) = managerInstance.stakingRewardsSplit();
        assertEq(treasury, 50000);
        assertEq(nodeOperator, 50000);
        assertEq(tnft, 815625);
        assertEq(bnft, 84375);

        vm.prank(owner);
        managerInstance.setStakingRewardsSplit(100000, 100000, 400000, 400000);

        (treasury, nodeOperator, tnft, bnft) = managerInstance.stakingRewardsSplit();
        assertEq(treasury, 100000);
        assertEq(nodeOperator, 100000);
        assertEq(tnft, 400000);
        assertEq(bnft, 400000);
    }

    function test_SetProtocolRewardsSplit() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 400000);

        vm.expectRevert("Amounts not equal to 1000000");
        vm.prank(owner);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 300000);

        (uint64 treasury, uint64 nodeOperator, uint64 tnft, uint64 bnft) = managerInstance.protocolRewardsSplit();
        assertEq(treasury, 250000);
        assertEq(nodeOperator, 250000);
        assertEq(tnft, 453125);
        assertEq(bnft, 46875);

        vm.prank(owner);
        managerInstance.setProtocolRewardsSplit(100000, 100000, 400000, 400000);

        (treasury, nodeOperator, tnft, bnft) = managerInstance.protocolRewardsSplit();
        assertEq(treasury, 100000);
        assertEq(nodeOperator, 100000);
        assertEq(tnft, 400000);
        assertEq(bnft, 400000);
    }

    function test_SetNonExitPenaltyPrincipal() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        managerInstance.setNonExitPenaltyPrincipal(2 ether);

        assertEq(managerInstance.nonExitPenaltyPrincipal(), 1 ether);

        vm.prank(owner);
        managerInstance.setNonExitPenaltyPrincipal(2 ether);

        assertEq(managerInstance.nonExitPenaltyPrincipal(), 2 ether);
    }

    function test_SetNonExitPenaltyDailyRate() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        managerInstance.setNonExitPenaltyDailyRate(2 ether);

        assertEq(managerInstance.nonExitPenaltyDailyRate(), 3);

        vm.prank(owner);
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

    function test_setEtherFiNodeLocalRevenueIndexRevertsOnIncorrectCaller() public {
        vm.expectRevert("Only protocol revenue manager contract function");
        vm.prank(owner);
        managerInstance.setEtherFiNodeLocalRevenueIndex(bidId[0], 1);
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
         bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
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
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
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

    // function test_SendExitRequestWorksCorrectly() public {
    //     assertEq(managerInstance.isExitRequested(bidId[0]), false);

    //     hoax(alice);
    //     vm.expectRevert("You are not the owner of the T-NFT");
    //     managerInstance.sendExitRequest(bidId[0]);

    //     hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     managerInstance.sendExitRequest(bidId[0]);

    //     assertEq(managerInstance.isExitRequested(bidId[0]), true);

    //     hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     vm.expectRevert("Exit request was already sent.");
    //     managerInstance.sendExitRequest(bidId[0]);

    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0);

    //     // 1 day passed
    //     vm.warp(1 + 86400);
    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0.03 ether);

    //     vm.warp(1 + 86400 + 3600);
    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0.03 ether);

    //     vm.warp(1 + 2 * 86400);
    //     assertEq(
    //         managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
    //         0.0591 ether
    //     );

    //     // 10 days passed
    //     vm.warp(1 + 10 * 86400);
    //     assertEq(
    //         managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
    //         0.262575873105071740 ether
    //     );

    //     // 28 days passed
    //     vm.warp(1 + 28 * 86400);
    //     assertEq(
    //         managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
    //         0.573804794831376551 ether
    //     );

    //     // 365 days passed
    //     vm.warp(1 + 365 * 86400);
    //     assertEq(
    //         managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
    //         0.999985151485507863 ether
    //     );

    //     // more than 1 year passed
    //     vm.warp(1 + 366 * 86400);
    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);

    //     vm.warp(1 + 400 * 86400);
    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);

    //     vm.warp(1 + 1000 * 86400);
    //     assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);
    // }
}