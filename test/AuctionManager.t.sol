// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/StakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract AuctionManagerTest is Test {
    StakingManager public stakingManagerInstance;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);

    string aliceIPFSHash = "AliceIPFS";
    string _ipfsHash = "ipfsHash";

    event BidCreated(
        address indexed bidder,
        uint256 amount,
        uint256[] indexed bidId,
        uint64[] indexed ipfsIndexArray
    );

    event SelectedBidUpdated(
        address indexed winner,
        uint256 indexed winningBidId
    );

    event MinBidUpdated(
        uint256 indexed oldMinBidAmount,
        uint256 indexed newMinBidAmount
    );
    event WhitelistBidUpdated(
        uint256 indexed oldBidAmount,
        uint256 indexed newBidAmount
    );

    function setUp() public {
        vm.startPrank(owner);

        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        auctionInstance.updateMerkleRoot(root);
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
            address(TestBNFTInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        vm.stopPrank();

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        vm.stopPrank();
    }

    function test_AuctionManagerContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfBids(), 1);
        assertEq(
            auctionInstance.stakingManagerContractAddress(),
            address(stakingManagerInstance)
        );
    }

    function test_ReEnterAuctionManagerFailsIfAuctionManagerPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);

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
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

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
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);
        uint256[] memory bidId2 = auctionInstance.createBidWhitelisted{
            value: 0.05 ether
        }(proof, 1, 0.05 ether);

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
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256[] memory bidId1 = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);
        uint256[] memory bidId2 = auctionInstance.createBidWhitelisted{
            value: 0.05 ether
        }(proof, 1, 0.05 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId1[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );
        (, , , bool isBid1Active) = auctionInstance.bids(bidId1[0]);

        uint256 selectedBidId = bidId1[0];
        assertEq(selectedBidId, 1);
        assertEq(isBid1Active, false);

        stakingManagerInstance.cancelDeposit(bidId1[0]);
        (, , , isBid1Active) = auctionInstance.bids(bidId1[0]);
        (, , , bool isBid2Active) = auctionInstance.bids(bidId2[0]);
        assertEq(isBid1Active, true);
        assertEq(isBid2Active, true);
        assertEq(address(auctionInstance).balance, 0.15 ether);
    }

    function test_CreateBidWhitelisted() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(alice);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.001 ether
        }(aliceProof, 1, 0.001 ether);

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
        assertEq(auctionInstance.numberOfBids(), 2);

        vm.expectRevert("Only whitelisted addresses");
        hoax(chad);
        auctionInstance.createBidWhitelisted{value: 0.001 ether}(
            bobProof,
            1,
            0.001 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            bid1Id[0]
        );

        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);
        assertEq(address(auctionInstance).balance, 0.001 ether);

        hoax(alice);
        auctionInstance.createBidWhitelisted{value: 0.001 ether}(
            aliceProof,
            1,
            0.001 ether
        );

        vm.expectRevert("Insufficient public keys");
        startHoax(alice);
        auctionInstance.createBidWhitelisted{value: 11 ether}(
            aliceProof,
            11,
            1 ether
        );
        vm.stopPrank();

        vm.expectRevert("Whitelist enabled");
        hoax(alice);
        auctionInstance.createBidPermissionless{value: 0.001 ether}(
            1,
            0.001 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (amount, , bidderAddress, ) = auctionInstance.bids(bid1Id[0]);

        assertEq(amount, 0.001 ether);
        assertEq(bidderAddress, alice);
        assertEq(address(auctionInstance).balance, 0.002 ether);
        vm.prank(owner);
        auctionInstance.disableWhitelist();

        vm.expectRevert("Whitelist disabled");
        hoax(bob);
        auctionInstance.createBidWhitelisted{value: 0.001 ether}(
            bobProof,
            1,
            0.001 ether
        );

        (, ipfsIndex, , ) = auctionInstance.bids(bid1Id[0]);
        assertEq(ipfsIndex, 0);

        assertEq(auctionInstance.numberOfActiveBids(), 2);
    }

    function test_createBidWhitelistedFailsIfIPFSIndexMoreThanTotalKeys()
        public
    {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 1);

        hoax(alice);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(aliceProof, 1, 0.1 ether);

        vm.expectRevert("All public keys used");
        hoax(alice);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            aliceProof,
            1,
            0.1 ether
        );

        vm.expectRevert("All public keys used");
        hoax(alice);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            aliceProof,
            1,
            0.1 ether
        );
    }

    function test_createBidWhitelistedBatch() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        startHoax(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        uint256[] memory bidIds = auctionInstance.createBidWhitelisted{
            value: 0.5 ether
        }(aliceProof, 5, 0.1 ether);

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
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        uint256[] memory bobBidIds = auctionInstance.createBidWhitelisted{
            value: 1 ether
        }(bobProof, 10, 0.1 ether);

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

    function test_createBidWhitelistedBatchFailsWithIncorrectValue() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        hoax(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBidWhitelisted{
            value: 0.4 ether
        }(aliceProof, 5, 0.1 ether);
    }

    function test_CreateBidPermissionless() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);
        vm.stopPrank();

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        startHoax(alice);
        uint256[] memory aliceBidIds = auctionInstance.createBidPermissionless{
            value: 0.005 ether
        }(5, 0.001 ether);
        vm.stopPrank();

        (
            uint256 amount,
            uint256 ipfsIndex,
            address bidderAddress,
            bool isActive
        ) = auctionInstance.bids(aliceBidIds[0]);

        assertEq(aliceBidIds.length, 5);

        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        startHoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBidPermissionless{
            value: 0.05 ether
        }(5, 0.01 ether);
        vm.stopPrank();

        (amount, ipfsIndex, bidderAddress, isActive) = auctionInstance.bids(
            chadBidIds[0]
        );

        assertEq(aliceBidIds.length, 5);

        assertEq(amount, 0.01 ether);
        assertEq(ipfsIndex, 0);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);
    }

    function test_CreateBidPermissionlessBatchFailsWithIncorrectValue() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);

        hoax(alice);
        uint256[] memory aliceBidIds = auctionInstance.createBidWhitelisted{
            value: 0.005 ether
        }(aliceProof, 5, 0.001 ether);

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        vm.expectRevert("Insufficient public keys");
        startHoax(alice);
        aliceBidIds = auctionInstance.createBidPermissionless{value: 11 ether}(
            11,
            1 ether
        );
        vm.stopPrank();

        startHoax(alice);
        aliceBidIds = auctionInstance.createBidPermissionless{
            value: 0.002 ether
        }(2, 0.001 ether);
        vm.stopPrank();

        vm.expectRevert("Only whitelisted addresses");
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBidPermissionless{
            value: 0.004 ether
        }(4, 0.001 ether);
        vm.stopPrank();

        vm.expectRevert("Incorrect bid value");
        hoax(alice);
        aliceBidIds = auctionInstance.createBidPermissionless{value: 0.4 ether}(
            5,
            0.1 ether
        );
        vm.stopPrank();

        vm.expectRevert("Incorrect bid value");
        startHoax(alice);
        aliceBidIds = auctionInstance.createBidPermissionless{
            value: 10.2 ether
        }(2, 5.1 ether);
        vm.stopPrank();
    }

    function test_EventBidPlaced() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        uint256[] memory bidIdArray = new uint256[](1);
        uint64[] memory ipfsIndexArray = new uint64[](1);

        bidIdArray[0] = 1;
        ipfsIndexArray[0] = 0;

        vm.expectEmit(true, true, true, true);
        emit BidCreated(alice, 0.2 ether, bidIdArray, ipfsIndexArray);
        hoax(alice);
        auctionInstance.createBidWhitelisted{value: 0.2 ether}(
            aliceProof,
            1,
            0.2 ether
        );
    }

    function test_PausableCreateBidWhitelisted() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        assertFalse(auctionInstance.paused());
        vm.prank(owner);
        auctionInstance.pauseContract();
        assertTrue(auctionInstance.paused());

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_CancelBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proof, 1, 0.1 ether);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(bid1Id[0]);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(bid1Id[0]);
    }

    function test_CancelBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

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
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofForAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );
        bytes32[] memory proofForAddress3 = merkle.getProof(
            whiteListedAddresses,
            2
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        vm.prank(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proofForAddress1, 1, 0.1 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bid2Id = auctionInstance.createBidWhitelisted{
            value: 0.3 ether
        }(proofForAddress2, 1, 0.3 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        uint256[] memory bid3Id = auctionInstance.createBidWhitelisted{
            value: 0.2 ether
        }(proofForAddress3, 1, 0.2 ether);
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
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofForAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );
        bytes32[] memory proofForAddress3 = merkle.getProof(
            whiteListedAddresses,
            2
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proofForAddress1, 1, 0.1 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bid2Id = auctionInstance.createBidWhitelisted{
            value: 0.3 ether
        }(proofForAddress2, 1, 0.3 ether);
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

    function test_UpdatingMerkleFailsIfNotOwner() public {
        assertEq(auctionInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        auctionInstance.updateMerkleRoot(newRoot);
    }

    function test_SetMinBidAmount() public {
        assertEq(auctionInstance.minBidAmount(), 0.01 ether);
        vm.prank(owner);
        auctionInstance.setMinBidPrice(1 ether);
        assertEq(auctionInstance.minBidAmount(), 1 ether);
    }

    function test_SetBidAmountFailsIfGreaterThanMaxBidAmount() public {
        vm.prank(owner);
        vm.expectRevert("Min bid exceeds max bid");
        auctionInstance.setMinBidPrice(5 ether);
    }

    function test_SetWhitelistBidAmount() public {
        assertEq(auctionInstance.whitelistBidAmount(), 0.001 ether);
        vm.prank(owner);
        auctionInstance.updateWhitelistMinBidAmount(0.002 ether);
        assertEq(auctionInstance.whitelistBidAmount(), 0.002 ether);
    }

    function test_SetWhitelistBidFailsWithIncorrectAmount() public {
        vm.prank(owner);
        vm.expectRevert("Invalid Amount");
        auctionInstance.updateWhitelistMinBidAmount(0);

        vm.prank(owner);
        vm.expectRevert("Invalid Amount");
        auctionInstance.updateWhitelistMinBidAmount(0.2 ether);
    }

    function test_EventWhitelistBidUpdated() public {
        vm.expectEmit(true, true, false, true);
        emit WhitelistBidUpdated(0.001 ether, 0.002 ether);
        vm.prank(owner);
        auctionInstance.updateWhitelistMinBidAmount(0.002 ether);
    }

    function test_EventMinBidUpdated() public {
        vm.expectEmit(true, true, false, true);
        emit MinBidUpdated(0.01 ether, 1 ether);
        vm.prank(owner);
        auctionInstance.setMinBidPrice(1 ether);
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
