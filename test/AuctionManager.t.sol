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
        treasuryInstance.setAuctionManagerContractAddress(
            address(auctionInstance)
        );
        auctionInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        auctionInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

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

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.cancelDeposit(bidId[0]);
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

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
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

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.cancelDeposit(bidId1[0]);
        vm.stopPrank();

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
        assertEq(auctionInstance.currentHighestBidId(), 1);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        (, , , , , bool isBid1Active) = auctionInstance.bids(bidId1[0]);

        uint256 selectedBidId = bidId1[0];
        assertEq(selectedBidId, 1);
        assertEq(isBid1Active, false);
        assertEq(auctionInstance.currentHighestBidId(), bidId2[0]);

        stakingManagerInstance.cancelDeposit(bidId1[0]);
        (, , , , , isBid1Active) = auctionInstance.bids(bidId1[0]);
        (, , , , , bool isBid2Active) = auctionInstance.bids(bidId2[0]);
        assertEq(isBid1Active, true);
        assertEq(isBid2Active, true);
        assertEq(address(auctionInstance).balance, 0.15 ether);
        assertEq(auctionInstance.currentHighestBidId(), bidId1[0]);
    }

    function test_FetchWinningBidFailsIfNotContractCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.fetchWinningBid();
    }

    function test_FetchWinningBidWorks() public {
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

        // Bid One
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.1 ether
        }(proofForAddress1, 1, 0.1 ether);
        assertEq(auctionInstance.currentHighestBidId(), 1);

        // Bid Two
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bid2Id = auctionInstance.createBidWhitelisted{
            value: 0.3 ether
        }(proofForAddress2, 1, 0.3 ether);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        // Bid Three
        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        uint256[] memory bid3Id = auctionInstance.createBidWhitelisted{
            value: 0.2 ether
        }(proofForAddress3, 1, 0.2 ether);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);
        vm.stopPrank();

        (, , , , , bool isActiveBid1) = auctionInstance.bids(bid1Id[0]);
        (, , , , , bool isActiveBid2) = auctionInstance.bids(bid2Id[0]);
        (, , , , , bool isActiveBid3) = auctionInstance.bids(bid3Id[0]);

        assertEq(auctionInstance.currentHighestBidId(), bid3Id[0]);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid2, false);
        assertEq(isActiveBid3, true);

        hoax(address(stakingManagerInstance));
        uint256 winner = auctionInstance.fetchWinningBid();

        (, , , , , isActiveBid1) = auctionInstance.bids(bid1Id[0]);
        (, , , , , isActiveBid3) = auctionInstance.bids(bid3Id[0]);

        assertEq(auctionInstance.currentHighestBidId(), bid1Id[0]);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid3, false);
        assertEq(winner, bid3Id[0]);
    }

    function test_EventWinningBidSent() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofForAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proofForAddress1,
            1,
            0.1 ether
        );

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.createBidWhitelisted{value: 0.3 ether}(
            proofForAddress2,
            1,
            0.3 ether
        );

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit SelectedBidUpdated(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, 1);
        hoax(address(stakingManagerInstance));
        auctionInstance.fetchWinningBid();
    }

    function test_CreateBidWhitelisted() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(bob);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(alice);
        uint256[] memory bid1Id = auctionInstance.createBidWhitelisted{
            value: 0.001 ether
        }(aliceProof, 1, 0.001 ether);

        assertEq(auctionInstance.currentHighestBidId(), bid1Id[0]);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (
            uint256 bidId,
            uint256 amount,
            uint256 ipfsIndex,
            uint256 timeOfCreation,
            address bidderAddress,
            bool isActive
        ) = auctionInstance.bids(bid1Id[0]);

        assertEq(bid1Id[0], 1);
        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(timeOfCreation, block.timestamp);
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

        vm.prank(owner);
        auctionInstance.disableWhitelist();

        vm.expectRevert("Whitelist disabled");
        hoax(bob);
        auctionInstance.createBidWhitelisted{value: 0.001 ether}(
            bobProof,
            1,
            0.001 ether
        );
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
            uint256 bidId,
            uint256 amount,
            uint256 ipfsIndex,
            uint256 timeOfCreation,
            address bidderAddress,
            bool isActive
        ) = auctionInstance.bids(bidIds[0]);

        assertEq(bidId, 1);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(timeOfCreation, block.timestamp);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bidIds[1]);

        assertEq(bidId, 2);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 1);
        assertEq(timeOfCreation, block.timestamp);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bidIds[2]);

        assertEq(bidId, 3);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 2);
        assertEq(timeOfCreation, block.timestamp);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bidIds[3]);

        assertEq(bidId, 4);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 3);
        assertEq(timeOfCreation, block.timestamp);
        assertEq(bidderAddress, alice);
        assertTrue(isActive);

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bidIds[4]);

        assertEq(bidId, 5);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 4);
        assertEq(timeOfCreation, block.timestamp);
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

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bobBidIds[0]);

        assertEq(bidId, 6);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(timeOfCreation, block.timestamp);
        assertEq(bidderAddress, bob);
        assertTrue(isActive);

        (
            bidId,
            amount,
            ipfsIndex,
            timeOfCreation,
            bidderAddress,
            isActive
        ) = auctionInstance.bids(bobBidIds[9]);

        assertEq(bidId, 15);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 9);
        assertEq(timeOfCreation, block.timestamp);
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

    function test_BidFailsWhenInvaliAmountSent() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        vm.expectRevert("Incorrect bid value");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 0}(proof, 1, 0);

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.expectRevert("Incorrect bid value");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBidWhitelisted{value: 5.01 ether}(
            proof,
            1,
            5.01 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 0);
    }

    function test_PausablecreateBidWhitelisted() public {
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

        (, , , , , bool isActive) = auctionInstance.bids(bid3Id[0]);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(
            0xCDca97f61d8EE53878cf602FF6BC2f260f10240B.balance,
            balanceBeforeCancellation += 0.2 ether
        );
    }

    function test_CancelBidWorksIfBidIsCurrentHighest() public {
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

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        uint256[] memory bid3Id = auctionInstance.createBidWhitelisted{
            value: 0.2 ether
        }(proofForAddress3, 1, 0.2 ether);
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        assertEq(auctionInstance.currentHighestBidId(), bid2Id[0]);

        vm.stopPrank();
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(bid2Id[0]);
        assertEq(auctionInstance.currentHighestBidId(), bid3Id[0]);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , , , bool isActive) = auctionInstance.bids(bid2Id[0]);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.3 ether);
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

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        uint256[] memory bid3Id = auctionInstance.createBidWhitelisted{
            value: 0.2 ether
        }(proofForAddress3, 1, 0.2 ether);

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(bid2Id[0]);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        assertEq(auctionInstance.numberOfActiveBids(), 3);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(bid2Id[0]);

        assertEq(auctionInstance.numberOfActiveBids(), 2);
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
        vm.expectRevert("Only owner function");
        auctionInstance.updateMerkleRoot(newRoot);
    }

    function test_UpdatingMerkle() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        assertEq(auctionInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        vm.prank(owner);
        auctionInstance.updateMerkleRoot(newRoot);

        bytes32[] memory proofForAddress4 = merkle.getProof(
            whiteListedAddresses,
            5
        );

        assertEq(auctionInstance.merkleRoot(), newRoot);

        vm.prank(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.createBidWhitelisted{value: 0.01 ether}(
            proofForAddress4,
            1,
            0.01 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_SetMinBidAmount() public {
        assertEq(auctionInstance.minBidAmount(), 0.01 ether);
        vm.prank(owner);
        auctionInstance.setMinBidPrice(1 ether);
        assertEq(auctionInstance.minBidAmount(), 1 ether);
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

    function test_SetBidAmountFailsIfGreaterThanMaxBidAmount() public {
        vm.prank(owner);
        vm.expectRevert("Min bid exceeds max bid");
        auctionInstance.setMinBidPrice(5 ether);
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
