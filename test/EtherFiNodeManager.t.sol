// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/EtherFiNode.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract EtherFiNodesManagerTest is Test {
    IStakingManager public depositInterface;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    EtherFiNode public safeInstance;
    Merkle merkle;
    bytes32 root;
    bytes32 salt =  0x1234567890123456789012345678901234567890123456789012345678901234;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);
    address etherFiNode;

    bytes _ipfsHash = "IPFSHash";

    uint256[] bidId;

    function setUp() public {
        vm.startPrank(owner);

        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorManagerInstance = new NodeOperatorManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorManagerInstance)
        );
        nodeOperatorManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        protocolRevenueManagerInstance = new ProtocolRevenueManager{salt:salt}();

        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestBNFTInstance),
            address(TestTNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );

        auctionInstance.setProtocolRevenueManager(
            address(protocolRevenueManagerInstance)
        );

        protocolRevenueManagerInstance.setAuctionManagerAddress(
            address(auctionInstance)
        );

        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        stakingManagerInstance.setProtocolRevenueManager(
            address(protocolRevenueManagerInstance)
        );

        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));
        vm.stopPrank();

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
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

        etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        assertTrue(
            managerInstance.phase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        assertTrue(
            managerInstance.phase(bidId[0]) ==
                IEtherFiNode.VALIDATOR_PHASE.LIVE
        );

        safeInstance = EtherFiNode(payable(etherFiNode));
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
        vm.expectRevert("Only staking manager contract function");
        vm.prank(owner);
        managerInstance.createEtherfiNode(bidId[0]);

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
        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidId);

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
        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidId);

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

        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0);

        // 1 day passed
        vm.warp(1 + 86400);
        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0.03 ether);

        vm.warp(1 + 86400 + 3600);
        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 0.03 ether);

        vm.warp(1 + 2 * 86400);
        assertEq(
            managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
            0.0591 ether
        );

        // 10 days passed
        vm.warp(1 + 10 * 86400);
        assertEq(
            managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
            0.262575873105071740 ether
        );

        // 28 days passed
        vm.warp(1 + 28 * 86400);
        assertEq(
            managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
            0.573804794831376551 ether
        );

        // 365 days passed
        vm.warp(1 + 365 * 86400);
        assertEq(
            managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)),
            0.999985151485507863 ether
        );

        // more than 1 year passed
        vm.warp(1 + 366 * 86400);
        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);

        vm.warp(1 + 400 * 86400);
        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);

        vm.warp(1 + 1000 * 86400);
        assertEq(managerInstance.getNonExitPenalty(bidId[0], uint32(block.timestamp)), 1 ether);
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