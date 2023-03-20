// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/AuctionManager.sol";
import "../src/BNFT.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract EtherFiNodeTest is Test {
    IStakingManager public depositInterface;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    AuctionManager public auctionInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    EtherFiNode public safeInstance;
    EtherFiNodesManager public managerInstance;

    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);

    bytes _ipfsHash = "ipfsHash";
    bytes aliceIPFSHash = "AliceIpfsHash";

    uint256[] bidId;

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        nodeOperatorKeyManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorKeyManagerInstance.updateMerkleRoot(root);
        protocolRevenueManagerInstance = new ProtocolRevenueManager();

        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        auctionInstance.setProtocolRevenueManager(
            address(protocolRevenueManagerInstance)
        );

        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        protocolRevenueManagerInstance.setAuctionManagerAddress(
            address(auctionInstance)
        );
        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        test_data_2 = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash_2"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.prank(owner);
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId[0]);

        assertTrue(
            managerInstance.getEtherFiNodePhase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        assertTrue(
            managerInstance.getEtherFiNodePhase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );

        safeInstance = EtherFiNode(payable(etherFiNode));

        assertEq(address(etherFiNode).balance, 0.05 ether);
        assertEq(
            managerInstance.getEtherFiNodeVestedAuctionRewards(bidId[0]),
            0.05 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId[0]
            ),
            0.05 ether
        );
        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.05 ether + 1
        );
    }

    function test_SetExitRequestTimestampFailsOnIncorrectCaller() public {
        vm.expectRevert("Only EtherFiNodeManager Contract");
        vm.prank(alice);
        safeInstance.setExitRequestTimestamp();
    }

    function test_EtherFiNodeMultipleSafesWorkCorrectly() public {
        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.05 ether + 1
        );

        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory chadProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            chadProof,
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        hoax(dan);
        bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        {
            address staker_2 = stakingManagerInstance.bidIdToStaker(bidId1[0]);
            address staker_3 = stakingManagerInstance.bidIdToStaker(bidId2[0]);
            assertEq(staker_2, bob);
            assertEq(staker_3, dan);
        }

        startHoax(bob);
        stakingManagerInstance.registerValidator(bidId1[0], test_data_2);
        vm.stopPrank();

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.15 ether + 1
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(1),
            0.15 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId1[0]
            ),
            0.1 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId2[0]
            ),
            0
        );
        assertEq(
            address(managerInstance.getEtherFiNodeAddress(bidId1[0])).balance,
            0.2 ether
        );

        startHoax(dan);
        stakingManagerInstance.registerValidator(bidId2[0], test_data_2);
        vm.stopPrank();

        assertEq(
            address(managerInstance.getEtherFiNodeAddress(bidId2[0])).balance,
            0.15 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(1),
            0.2 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId1[0]
            ),
            0.15 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId2[0]
            ),
            0.05 ether
        );
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

        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0);

        // 1 day passed
        vm.warp(1 + 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.03 ether);

        vm.warp(1 + 86400 + 3600);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.03 ether);

        vm.warp(1 + 2 * 86400);
        assertEq(
            managerInstance.getNonExitPenaltyAmount(bidId[0]),
            0.0591 ether
        );

        // 10 days passed
        vm.warp(1 + 10 * 86400);
        assertEq(
            managerInstance.getNonExitPenaltyAmount(bidId[0]),
            0.262575873105071740 ether
        );

        // 28 days passed
        vm.warp(1 + 28 * 86400);
        assertEq(
            managerInstance.getNonExitPenaltyAmount(bidId[0]),
            0.573804794831376551 ether
        );

        // 365 days passed
        vm.warp(1 + 365 * 86400);
        assertEq(
            managerInstance.getNonExitPenaltyAmount(bidId[0]),
            0.999985151485507863 ether
        );

        // more than 1 year passed
        vm.warp(1 + 366 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);

        vm.warp(1 + 400 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);

        vm.warp(1 + 1000 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);
    }

    function test_markExitedWorksCorrectly() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherFiNode = managerInstance.getEtherFiNodeAddress(validatorIds[0]);

        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);

        vm.expectRevert("Only EtherFiNodeManager Contract");
        IEtherFiNode(etherFiNode).markExited(1);

        vm.expectRevert("Only owner function");
        managerInstance.markExited(validatorIds, exitTimestamps);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() == 0);

        hoax(owner);
        managerInstance.markExited(validatorIds, exitTimestamps);
        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED);
        assertTrue(IEtherFiNode(etherFiNode).exitTimestamp() > 0);
    }

    function test_partialWithdraw() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;
        address etherfiNode = managerInstance.getEtherFiNodeAddress(bidId[0]);

        uint256 accreudProtocolRewards = protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId[0]
            );
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode)
            .vestedAuctionRewards();
        assertEq(
            vestedAuctionFeeRewardsForStakers,
            address(etherfiNode).balance
        );

        // Transfer the T-NFT to 'dan'
        hoax(staker);
        TestTNFTInstance.transferFrom(staker, dan, bidId[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        // Simulate the rewards distribution from the beacon chain
        vm.deal(etherfiNode, 1 ether + vestedAuctionFeeRewardsForStakers);

        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(
            address(nodeOperator).balance,
            nodeOperatorBalance + 0.05 ether + 0.0125 ether
        );
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + 0.05 ether + 0.0125 ether
        );
        assertEq(address(dan).balance, danBalance + 0.838281250000000000 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 0.086718750000000000 ether);

        vm.deal(etherfiNode, 8 ether + vestedAuctionFeeRewardsForStakers);
        vm.expectRevert(
            "The accrued staking rewards are above 8 ETH. You should exit the node."
        );
        managerInstance.partialWithdraw(bidId[0]);
    }

    function test_partialWithdrawAfterExitRequest() public {
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;
        address etherfiNode = managerInstance.getEtherFiNodeAddress(bidId[0]);

        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode)
            .vestedAuctionRewards();
        assertEq(
            vestedAuctionFeeRewardsForStakers,
            address(etherfiNode).balance
        );

        // Simulate the rewards distribution from the beacon chain
        vm.deal(etherfiNode, address(etherfiNode).balance + 1 ether);

        // Transfer the T-NFT to 'dan'
        hoax(staker);
        TestTNFTInstance.transferFrom(staker, dan, bidId[0]);

        // Send Exit Request and wait for 14 days to pass
        hoax(dan);
        managerInstance.sendExitRequest(bidId[0]);
        vm.warp(1 + 14 * 86400);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(address(nodeOperator).balance, nodeOperatorBalance + 0.0125 ether);
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + 0.05 ether + 0.05 ether + 0.0125 ether
        );
        assertEq(address(dan).balance, danBalance + 0.838281250000000000 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 0.086718750000000000 ether);

        // No rewards left after calling the 'partialWithdraw'
        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(address(nodeOperator).balance, nodeOperatorBalance + 0.0125 ether);
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + 0.05 ether + 0.05 ether + 0.0125 ether
        );
        assertEq(address(dan).balance, danBalance + 0.838281250000000000 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 0.086718750000000000 ether);
        assertEq(address(etherfiNode).balance, vestedAuctionFeeRewardsForStakers);

        vm.warp(1 + 6 * 28 * 24 * 3600);
        hoax(owner);
        managerInstance.partialWithdraw(bidId[0]);
        assertEq(address(nodeOperator).balance, nodeOperatorBalance + 0.0125 ether);
        assertEq(
            address(treasuryInstance).balance,
            treasuryBalance + 0.05 ether + 0.05 ether + 0.0125 ether
        );
        assertEq(address(dan).balance, danBalance + 0.838281250000000000 ether + 0.045312500000000000 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 0.086718750000000000 ether + 0.004687500000000000 ether);
        assertEq(address(etherfiNode).balance, 0);

        vm.deal(etherfiNode, 8 ether + vestedAuctionFeeRewardsForStakers);
        vm.expectRevert(
            "The accrued staking rewards are above 8 ETH. You should exit the node."
        );
        managerInstance.partialWithdraw(bidId[0]);
    }

    function test_getFullWithdrawalPayoutsFails() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        address etherfiNode = managerInstance.getEtherFiNodeAddress(
            validatorIds[0]
        );
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode)
            .vestedAuctionRewards();

        vm.deal(etherfiNode, 16 ether - 1);
        vm.expectRevert("not enough balance for full withdrawal");
        managerInstance.fullWithdraw(validatorIds[0]);

        vm.deal(etherfiNode, 16 ether + vestedAuctionFeeRewardsForStakers);
        vm.expectRevert("validator node is not exited");
        managerInstance.fullWithdraw(validatorIds[0]);
    }

    function test_getFullWithdrawalPayoutsWorksCorrectly() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = 1;
        address etherfiNode = managerInstance.getEtherFiNodeAddress(validatorIds[0]);
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode).vestedAuctionRewards();

        hoax(owner);
        managerInstance.markExited(validatorIds, exitTimestamps);

        // 1. balance > 32 ether
        vm.deal(etherfiNode, 33 ether + vestedAuctionFeeRewardsForStakers);
        assertEq(
            address(etherfiNode).balance,
            33 ether + vestedAuctionFeeRewardsForStakers
        );

        (
            uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
        ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.05 ether);
        assertEq(toTreasury, 0.05 ether);
        assertEq(toTnft, 30.815625000000000000 ether);
        assertEq(toBnft, 2.084375000000000000 ether);

        // 2. balance > 31.5 ether
        vm.deal(etherfiNode, 31.75 ether + vestedAuctionFeeRewardsForStakers);
        assertEq(
            address(etherfiNode).balance,
            31.75 ether + vestedAuctionFeeRewardsForStakers
        );

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 30 ether);
        assertEq(toBnft, 1.75 ether);

        // 3. balance > 26 ether
        vm.deal(etherfiNode, 28.5 ether + vestedAuctionFeeRewardsForStakers);
        assertEq(
            address(etherfiNode).balance,
            28.5 ether + vestedAuctionFeeRewardsForStakers
        );

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 27 ether);
        assertEq(toBnft, 1.5 ether);

        // 4. balance > 25.5 ether
        vm.deal(etherfiNode, 25.75 ether + vestedAuctionFeeRewardsForStakers);
        assertEq(
            address(etherfiNode).balance,
            25.75 ether + vestedAuctionFeeRewardsForStakers
        );
        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 24.5 ether);
        assertEq(toBnft, 1.25 ether);

        // 5. balance > 16 ether
        vm.deal(etherfiNode, 18.5 ether + vestedAuctionFeeRewardsForStakers);
        assertEq(
            address(etherfiNode).balance,
            18.5 ether + vestedAuctionFeeRewardsForStakers
        );

        (toNodeOperator, toTnft, toBnft, toTreasury) = managerInstance
            .getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0);
        assertEq(toTreasury, 0);
        assertEq(toTnft, 17.5 ether);
        assertEq(toBnft, 1 ether);

        // Full Withdraw
        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        address staker = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf;

        hoax(staker);
        TestTNFTInstance.transferFrom(staker, dan, bidId[0]);

        uint256 nodeOperatorBalance = address(nodeOperator).balance;
        uint256 treasuryBalance = address(treasuryInstance).balance;
        uint256 danBalance = address(dan).balance;
        uint256 bnftStakerBalance = address(staker).balance;

        managerInstance.fullWithdraw(validatorIds[0]);
        assertEq(address(nodeOperator).balance, nodeOperatorBalance + 0);
        assertEq(address(treasuryInstance).balance, treasuryBalance + 0);
        assertEq(address(dan).balance, danBalance + 17.5 ether);
        assertEq(address(staker).balance, bnftStakerBalance + 1 ether);
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly1()
        public
    {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        address etherfiNode = managerInstance.getEtherFiNodeAddress(validatorIds[0]);
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode).vestedAuctionRewards();

        hoax(TestTNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 1 day passed
        vm.warp(1 + 86400);
        startHoax(owner);
        exitTimestamps[0] = 1 + 86400;
        managerInstance.markExited(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenaltyAmount(bidId[0]);

        vm.deal(etherfiNode, 33 ether + vestedAuctionFeeRewardsForStakers);

        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.05 ether + nonExitPenalty);
        assertEq(toTreasury, 0.05 ether);
        assertEq(toTnft, 30.815625000000000000 ether);
        assertEq(toBnft, 2.084375000000000000 ether - nonExitPenalty);
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly2()
        public
    {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        address etherfiNode = managerInstance.getEtherFiNodeAddress(validatorIds[0]);
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode).vestedAuctionRewards();

        hoax(TestTNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 14 days passed
        vm.warp(1 + 14 * 86400);
        startHoax(owner);
        exitTimestamps[0] = 1 + 14 * 86400;
        managerInstance.markExited(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenaltyAmount(bidId[0]);

        vm.deal(etherfiNode, 33 ether + vestedAuctionFeeRewardsForStakers);

        (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.347163722539392386 ether);
        assertEq(toTreasury, 0.05 ether + 0.05 ether);
        assertEq(toTnft, 30.815625000000000000 ether);
        assertEq(toBnft, 2.084375000000000000 ether - nonExitPenalty);
    }

    function test_markExitedFails() public {
        uint256[] memory validatorIds = new uint256[](1);
        uint32[] memory exitTimestamps = new uint32[](2);
        startHoax(owner);
        vm.expectRevert("_validatorIds.length != _exitTimestamps.length");
        managerInstance.markExited(validatorIds, exitTimestamps);
    }

    function test_getFullWithdrawalPayoutsWorksWithNonExitPenaltyCorrectly3() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = bidId[0];
        uint32[] memory exitTimestamps = new uint32[](1);
        address etherfiNode = managerInstance.getEtherFiNodeAddress(validatorIds[0]);
        uint256 vestedAuctionFeeRewardsForStakers = IEtherFiNode(etherfiNode).vestedAuctionRewards();

        hoax(TestTNFTInstance.ownerOf(validatorIds[0]));
        managerInstance.sendExitRequest(validatorIds[0]);

        // 28 days passed
        vm.warp(1 + 28 * 86400);
        startHoax(owner);
        exitTimestamps[0] = 1 + 28 * 86400;
        managerInstance.markExited(validatorIds, exitTimestamps);
        uint256 nonExitPenalty = managerInstance.getNonExitPenaltyAmount(bidId[0]);
        assertGe(nonExitPenalty, 0.5 ether);

        vm.deal(etherfiNode, 33 ether + vestedAuctionFeeRewardsForStakers);

        (
            uint256 toNodeOperator,
            uint256 toTnft,
            uint256 toBnft,
            uint256 toTreasury
        ) = managerInstance.getFullWithdrawalPayouts(validatorIds[0]);
        assertEq(toNodeOperator, 0.5 ether);
        assertEq(
            toTreasury,
            0.05 ether + (nonExitPenalty - 0.5 ether) + 0.05 ether
        );
        assertEq(toTnft, 30.815625000000000000 ether);
        assertEq(toBnft, 2.084375000000000000 ether - nonExitPenalty);
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)
            )
        );

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(chad)));

        root = merkle.getRoot(whiteListedAddresses);
    }
}
