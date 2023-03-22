// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/StakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract AuctionManagerTest is Test {
    StakingManager public stakingManagerInstance;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);

    bytes aliceIPFSHash = "AliceIPFS";
    bytes _ipfsHash = "ipfsHash";

    // event BidCreated(
    //     address indexed bidder,
    //     uint256 amountPerBid,
    //     uint256[] indexed bidIdArray,
    //     uint64[] indexed ipfsIndexArray
    // );

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
        protocolRevenueManagerInstance = new ProtocolRevenueManager();
        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        protocolRevenueManagerInstance = new ProtocolRevenueManager();
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        vm.expectEmit(true, false, false, true);
        emit StakingManagerAddressSet(address(stakingManagerInstance));
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
        vm.stopPrank();

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });
    }

    function test_AuctionManagerContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfBids(), 1);
        assertEq(
            auctionInstance.stakingManagerContractAddress(),
            address(stakingManagerInstance)
        );
        assertEq(auctionInstance.whitelistBidAmount(), 0.001 ether);
        assertEq(auctionInstance.minBidAmount(), 0.01 ether);
        assertEq(auctionInstance.whitelistBidAmount(), 0.001 ether);
        assertEq(auctionInstance.maxBidAmount(), 5 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 0);
        assertTrue(auctionInstance.whitelistEnabled());
    }

    function test_ReEnterAuctionManagerFailsIfAuctionManagerPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        vm.prank(owner);
        auctionInstance.pauseContract();

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        vm.prank(address(stakingManagerInstance));
        vm.expectRevert("Pausable: paused");
        auctionInstance.reEnterAuction(bidId[0]);
    }

    function test_ReEnterAuctionManagerFailsIfNotCorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only staking manager contract function");
        auctionInstance.reEnterAuction(1);
    }

    function test_ReEnterAuctionManagerFailsIfBidAlreadyActive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidId2 = auctionInstance.createBid{value: 0.05 ether}(
            1,
            0.05 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId1[0];
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        vm.stopPrank();

        vm.prank(address(stakingManagerInstance));
        auctionInstance.reEnterAuction(bidId1[0]);

        vm.prank(address(stakingManagerInstance));
        vm.expectRevert("Bid already active");
        auctionInstance.reEnterAuction(bidId1[0]);
    }

    function test_ReEnterAuctionManagerWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidId2 = auctionInstance.createBid{value: 0.05 ether}(
            1,
            0.05 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId1[0];

        assertEq(auctionInstance.numberOfActiveBids(), 2);

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (, , , bool isBid1Active) = auctionInstance.bids(bidId1[0]);
        uint256 selectedBidId = bidId1[0];
        assertEq(selectedBidId, 1);
        assertEq(isBid1Active, false);

        stakingManagerInstance.cancelDeposit(bidId1[0]);

        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , isBid1Active) = auctionInstance.bids(bidId1[0]);
        (, , , bool isBid2Active) = auctionInstance.bids(bidId2[0]);
        assertEq(isBid1Active, true);
        assertEq(isBid2Active, true);
        assertEq(address(auctionInstance).balance, 0.15 ether);
    }

    function test_DisableWhitelist() public {
        assertTrue(auctionInstance.whitelistEnabled());

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        auctionInstance.disableWhitelist();

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        assertFalse(auctionInstance.whitelistEnabled());
    }

    function test_EnableWhitelist() public {
        assertTrue(auctionInstance.whitelistEnabled());

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        assertFalse(auctionInstance.whitelistEnabled());

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        auctionInstance.enableWhitelist();

        vm.prank(owner);
        auctionInstance.enableWhitelist();

        assertTrue(auctionInstance.whitelistEnabled());
    }

    function test_createBidWorks() public {
        bytes32[] memory emptyProof = new bytes32[](0);
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );

        vm.prank(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            _ipfsHash,
            5
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            emptyProof,
            _ipfsHash,
            5
        );

        assertFalse(nodeOperatorManagerInstance.isWhitelisted(chad));
        assertTrue(nodeOperatorManagerInstance.isWhitelisted(alice));

        hoax(alice);
        uint256[] memory bid1Id = auctionInstance.createBid{value: 0.001 ether}(
            1,
            0.001 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (
            uint256 amount,
            uint64 ipfsIndex,
            address bidderAddress,
            bool isActive
        ) = auctionInstance.bids(bid1Id[0]);

        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        hoax(alice);
        auctionInstance.createBid{value: 0.004 ether}(4, 0.001 ether);

        vm.expectRevert("Insufficient public keys");
        startHoax(alice);
        auctionInstance.createBid{value: 1 ether}(1, 1 ether);
        vm.stopPrank();

        assertTrue(auctionInstance.whitelistEnabled());

        vm.expectRevert("Only whitelisted addresses");
        hoax(chad);
        auctionInstance.createBid{value: 0.01 ether}(1, 0.01 ether);

        assertEq(auctionInstance.numberOfActiveBids(), 5);

        // Owner disables whitelist
        vm.prank(owner);
        auctionInstance.disableWhitelist();

        // Bob can still bid below min bid amount because he was whitlelisted
        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{
            value: 0.001 ether
        }(1, 0.001 ether);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bobBidIds[0]
        );
        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, bob);
        assertTrue(isActive);

        assertEq(auctionInstance.numberOfActiveBids(), 6);

        // Chad cannot bid below the min bid amount because he was not whitelisted
        vm.expectRevert("Incorrect bid value");
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{
            value: 0.001 ether
        }(1, 0.001 ether);

        hoax(chad);
        chadBidIds = auctionInstance.createBid{value: 0.01 ether}(
            1,
            0.01 ether
        );
        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            chadBidIds[0]
        );
        assertEq(amount, 0.01 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, chad);
        assertTrue(isActive);

        // Owner enables whitelist
        vm.prank(owner);
        auctionInstance.enableWhitelist();

        vm.expectRevert("Only whitelisted addresses");
        hoax(chad);
        auctionInstance.createBid{value: 0.01 ether}(1, 0.01 ether);

        hoax(bob);
        bobBidIds = auctionInstance.createBid{value: 0.001 ether}(
            1,
            0.001 ether
        );

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bobBidIds[0]
        );
        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 1);
        assertEq(bidderAddress, bob);
        assertTrue(isActive);
    }

    function test_CreateBidMinMaxAmounts() public {
        bytes32[] memory emptyProof = new bytes32[](0);
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            emptyProof,
            _ipfsHash,
            5
        );

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        auctionInstance.createBid{value: 0.00001 ether}(1, 0.00001 ether);

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        auctionInstance.createBid{value: 5.1 ether}(1, 5.1 ether);

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        auctionInstance.createBid{value: 5.1 ether}(1, 5.1 ether);

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        auctionInstance.createBid{value: 0.00001 ether}(1, 0.00001 ether);

        vm.expectRevert("Incorrect bid value");
        hoax(chad);
        auctionInstance.createBid{value: 0.001 ether}(1, 0.001 ether);

        vm.expectRevert("Incorrect bid value");
        hoax(chad);
        auctionInstance.createBid{value: 5.1 ether}(1, 5.1 ether);
    }

    function test_CreateBidPauseable() public {
         bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            3
        );

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(
            2,
            0.1 ether
        );
    }

    function test_createBidFailsIfBidSizeIsLargerThanKeysRemaining() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            3
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(
            2,
            0.1 ether
        );

        (uint256 amount, uint64 ipfsIndex, address bidderAddress, bool isActive) = auctionInstance.bids(bidIds[0]);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        vm.expectRevert("Insufficient public keys");
        hoax(alice);
        auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
    }

    function test_createBidFailsIfIPFSIndexMoreThanTotalKeys() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            1
        );

        hoax(alice);
        uint256[] memory bid1Id = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        vm.expectRevert("Insufficient public keys");
        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.expectRevert("Insufficient public keys");
        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
    }

    function test_createBidBatch() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        startHoax(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            10
        );

        uint256[] memory bidIds = auctionInstance.createBid{value: 0.5 ether}(
            5,
            0.1 ether
        );

        vm.stopPrank();

        (
            uint256 amount,
            uint64 ipfsIndex,
            address bidderAddress,
            bool isActive
        ) = auctionInstance.bids(bidIds[0]);

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bidIds[1]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 1);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bidIds[2]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 2);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bidIds[3]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 3);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bidIds[4]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 4);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        assertEq(bidIds.length, 5);

        startHoax(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            aliceIPFSHash,
            10
        );

        uint256[] memory bobBidIds = auctionInstance.createBid{value: 1 ether}(
            10,
            0.1 ether
        );

        vm.stopPrank();

        assertEq(bobBidIds.length, 10);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bobBidIds[0]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, bob);
        assertTrue(isActive);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bobBidIds[9]
        );

        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 9);
        assertEq(bidderAddress, bob);
        assertTrue(isActive);
    }

    function test_createBidBatchFailsWithIncorrectValue() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        hoax(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            10
        );

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.4 ether}(
            5,
            0.1 ether
        );
    }

    function test_EventBidPlaced() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        assertFalse(auctionInstance.paused());
        vm.prank(owner);
        auctionInstance.pauseContract();
        assertTrue(auctionInstance.paused());

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_CancelBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(bid1Id[0]);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(bid1Id[0]);
    }

    function test_CancelBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);
    }

    function test_CancelBidFailsWhenNotExistingBid() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);
    }

    function test_CancelBidWorksIfBidIsNotCurrentHighest() public {
        bytes32[] memory proofAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );
        bytes32[] memory proofAddress3 = merkle.getProof(
            whiteListedAddresses,
            2
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress1,
            aliceIPFSHash,
            5
        );

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress2,
            aliceIPFSHash,
            5
        );

        vm.prank(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress3,
            aliceIPFSHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bid2Id = auctionInstance.createBid{value: 0.3 ether}(
            1,
            0.3 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        uint256[] memory bid3Id = auctionInstance.createBid{value: 0.2 ether}(
            1,
            0.2 ether
        );
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        uint256 balanceBeforeCancellation = 0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
                .balance;
        auctionInstance.cancelBid(bid3Id[0]);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , bool isActive) = auctionInstance.bids(bid3Id[0]);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(
            0xCDca97f61d8EE53878cf602FF6BC2f260f10240B.balance,
            balanceBeforeCancellation += 0.2 ether
        );
    }

    function test_PausableCancelBid() public {
        bytes32[] memory proofAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );
        bytes32[] memory proofAddress3 = merkle.getProof(
            whiteListedAddresses,
            2
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress1,
            _ipfsHash,
            5
        );

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress2,
            _ipfsHash,
            5
        );

        vm.prank(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofAddress3,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bid2Id = auctionInstance.createBid{value: 0.3 ether}(
            1,
            0.3 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(bid2Id[0]);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        assertEq(auctionInstance.numberOfActiveBids(), 2);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(bid2Id[0]);

        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_ProcessAuctionFeeTransfer() public {
        bytes32[] memory proofAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            proofAddress1,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Ids = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );

        vm.prank(owner);
        vm.expectRevert("Only staking manager contract function");
        auctionInstance.processAuctionFeeTransfer(bid1Ids[0]);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory processedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bid1Ids);

        stakingManagerInstance.registerValidator(processedBidIds[0], test_data);

        address safe = managerInstance.getEtherFiNodeAddress(processedBidIds[0]);
        assertEq(safe.balance, 0.5 ether);
    }

    function test_SetMaxBidAmount() public {
        vm.prank(owner);
        vm.expectRevert("Min bid exceeds max bid");
        auctionInstance.setMaxBidPrice(0.001 ether);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        auctionInstance.setMaxBidPrice(10 ether);

        assertEq(auctionInstance.maxBidAmount(), 5 ether);
        vm.prank(owner);
        auctionInstance.setMaxBidPrice(10 ether);
        assertEq(auctionInstance.maxBidAmount(), 10 ether);
    }

    function test_SetMinBidAmount() public {
        vm.prank(owner);
        vm.expectRevert("Min bid exceeds max bid");
        auctionInstance.setMinBidPrice(5 ether);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        auctionInstance.setMinBidPrice(0.005 ether);

        assertEq(auctionInstance.minBidAmount(), 0.01 ether);
        vm.prank(owner);
        auctionInstance.setMinBidPrice(1 ether);
        assertEq(auctionInstance.minBidAmount(), 1 ether);
    }

    function test_SetWhitelistBidAmount() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        auctionInstance.updateWhitelistMinBidAmount(0.005 ether);

        vm.prank(owner);
        vm.expectRevert("Invalid Amount");
        auctionInstance.updateWhitelistMinBidAmount(0);

        vm.prank(owner);
        vm.expectRevert("Invalid Amount");
        auctionInstance.updateWhitelistMinBidAmount(0.2 ether);

        assertEq(auctionInstance.whitelistBidAmount(), 0.001 ether);
        vm.prank(owner);
        auctionInstance.updateWhitelistMinBidAmount(0.002 ether);
        assertEq(auctionInstance.whitelistBidAmount(), 0.002 ether);
    }

    function test_EventBidPlaced() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        uint256[] memory bidIdArray = new uint256[](1);
        uint64[] memory ipfsIndexArray = new uint64[](1);

        bidIdArray[0] = 1;
        ipfsIndexArray[0] = 0;

        vm.expectEmit(true, true, true, true);
        emit BidCreated(alice, 0.2 ether, bidIdArray, ipfsIndexArray);
        hoax(alice);
        auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
    }

    function test_EventSelectedBidUpdated() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);

        vm.expectEmit(true, true, false, true);
        emit SelectedBidUpdated(alice, 1);
        hoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIds);
    }

    function test_EventBidReEnteredAuction() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);

        startHoax(bob);
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIds);

        vm.expectEmit(true, false, false, true);
        emit BidReEnteredAuction(bidIds[0]);
        stakingManagerInstance.cancelDeposit(bidIds[0]);
    }

    function test_EventBidCancelled() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            5
        );

        startHoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);

        vm.expectEmit(true, false, false, true);
        emit BidCancelled(bidIds[0]);
        auctionInstance.cancelBid(bidIds[0]);      
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

        whiteListedAddresses.push(keccak256(abi.encodePacked(bob)));

        root = merkle.getRoot(whiteListedAddresses);
    }
}
