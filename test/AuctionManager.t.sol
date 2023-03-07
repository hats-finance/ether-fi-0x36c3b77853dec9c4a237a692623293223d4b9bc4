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

    string aliceIPFSHash = "aliceIPFSHash";

    event BidCreated(
        uint256 indexed _bidId,
        uint256 indexed amount,
        address indexed bidderAddress,
        uint256 nextAvailableIpfsIndex
    );

    event WinningBidSent(address indexed winner, uint256 indexed winningBidId);

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
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
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

    function test_CreateBid() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        (, , uint256 keysUsed) = nodeOperatorKeyManagerInstance
            .addressToOperatorData(alice);

        assertEq(keysUsed, 0);

        hoax(alice);
        uint256 bid1Id = auctionInstance.createBid{value: 0.1 ether}(proof);

        (
            uint256 bidId,
            uint256 amount,
            uint256 pubKeyIndex,
            uint256 timeOfBid,
            bool isActive,
            bool isReserved,
            address bidder,
            address staker
        ) = auctionInstance.bids(bid1Id);

        assertEq(bid1Id, bidId);
        assertEq(amount, 0.1 ether);
        assertEq(pubKeyIndex, 0);
        assertEq(timeOfBid, block.timestamp);
        assertEq(isActive, true);
        assertEq(isReserved, false);
        assertEq(bidder, alice);
        assertEq(staker, address(0));

        hoax(alice);
        uint256 bid2Id = auctionInstance.createBid{value: 1 ether}(proof);

        (
            uint256 bidId2,
            uint256 amount2,
            uint256 pubKeyIndex2,
            uint256 timeOfBid2,
            bool isActive2,
            bool isReserved2,
            address bidderAddress,
            address stakerAddress
        ) = auctionInstance.bids(bid2Id);

        assertEq(bid2Id, bidId2);
        assertEq(amount2, 1 ether);
        assertEq(pubKeyIndex2, 1);
        assertEq(timeOfBid2, block.timestamp);
        assertEq(isActive2, true);
        assertEq(isReserved2, false);
        assertEq(bidderAddress, alice);
        assertEq(stakerAddress, address(0));
    }

    function test_CreateBidNonWhitelist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(proof);

        (
            uint256 bidId,
            uint256 amount,
            uint256 ipfsIndex,
            uint256 timeOfBid,
            bool isActive,
            bool isReserved,
            address bidderAddress,
            address staker
        ) = auctionInstance.bids(1);

        assertEq(bidId, 1);
        assertEq(amount, 0.1 ether);
        assertEq(ipfsIndex, 0);
        assertEq(timeOfBid, block.timestamp);
        assertTrue(isActive);
        assertFalse(isReserved);
        assertEq(bidderAddress, address(alice));
        assertEq(staker, address(0));
        assertEq(auctionInstance.numberOfBids(), 2);

        vm.expectRevert("Invalid bid");
        hoax(alice);
        auctionInstance.createBid{value: 0.001 ether}(proof);
    }

    function test_CreateBidWhitelist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.001 ether}(proof);

        (
            uint256 bidId,
            uint256 amount,
            uint256 ipfsIndex,
            uint256 timeOfBid,
            bool isActive,
            bool isReserved,
            address bidderAddress,
            address staker
        ) = auctionInstance.bids(1);

        assertEq(bidId, 1);
        assertEq(amount, 0.001 ether);
        assertEq(ipfsIndex, 0);
        assertEq(timeOfBid, block.timestamp);
        assertTrue(isActive);
        assertFalse(isReserved);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(staker, address(0));
    }

    function test_CreateBidFailsOnInvalidAmount() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.expectRevert("Invalid bid");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0}(proof);

        vm.expectRevert("Invalid bid");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 5.01 ether}(proof);
    }

    function test_EventBidCreated() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        vm.expectEmit(true, true, true, true);
        emit BidCreated(1, 0.1 ether, alice, 0);
        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(proof);
    }

    function test_ReEnterAuctionManagerFailsIfAuctionManagerPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        vm.prank(owner);
        auctionInstance.pauseContract();

        stakingManagerInstance.deposit{value: 0.032 ether}();
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.cancelDeposit(0);
    }

    function test_ReEnterAuctionManagerFailsIfNotCorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        stakingManagerInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.reEnterAuction(1);
    }

    function test_ReEnterAuctionManagerFailsIfBidAlreadyActive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.bidOnStake{value: 0.05 ether}(proof);

        stakingManagerInstance.deposit{value: 0.032 ether}();
        stakingManagerInstance.cancelDeposit(0);
        vm.stopPrank();

        vm.prank(address(stakingManagerInstance));
        vm.expectRevert("Bid already active");
        auctionInstance.reEnterAuction(2);
    }

    function test_ReEnterAuctionManagerWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.bidOnStake{value: 0.05 ether}(proof);
        assertEq(auctionInstance.currentHighestBidId(), 1);

        stakingManagerInstance.deposit{value: 0.032 ether}();
        (
            uint256 bidId,
            uint256 amount,
            uint256 ipfsIndex,
            uint256 timeOfBid,
            bool isBid1Active,
            bool isReserved,
            address bidderAddress,
            address staker
        ) = auctionInstance.bids(1);
        (, uint256 selectedBidId, , , , ) = stakingManagerInstance.validators(
            0
        );
        assertEq(selectedBidId, 1);
        assertEq(isBid1Active, false);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        stakingManagerInstance.cancelDeposit(0);
        (, , , , isBid1Active, , , ) = auctionInstance.bids(1);
        (, , , , bool isBid2Active, , , ) = auctionInstance.bids(2);
        assertEq(isBid1Active, true);
        assertEq(isBid2Active, true);
        assertEq(address(auctionInstance).balance, 0.15 ether);
        assertEq(auctionInstance.currentHighestBidId(), 1);
    }

    function test_CalculateWinningBidFailsIfNotContractCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        stakingManagerInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.calculateWinningBid();
    }

    function test_CalculateWinningBidWorks() public {
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

        // Bid One
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        assertEq(auctionInstance.currentHighestBidId(), 1);

        // Bid Two
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        // Bid Three
        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        stakingManagerInstance.deposit{value: 0.032 ether}();

        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);
        vm.stopPrank();

        (, , , , bool isActiveBid1, , , ) = auctionInstance.bids(1);
        (, , , , bool isActiveBid2, , , ) = auctionInstance.bids(2);
        (, , , , bool isActiveBid3, , , ) = auctionInstance.bids(3);

        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid2, false);
        assertEq(isActiveBid3, true);

        hoax(address(stakingManagerInstance));
        uint256 winner = auctionInstance.calculateWinningBid();

        (, , , , isActiveBid1, , , ) = auctionInstance.bids(1);
        (, , , , isActiveBid3, , , ) = auctionInstance.bids(3);

        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid3, false);
        assertEq(winner, 3);
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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);

        stakingManagerInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit WinningBidSent(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, 1);
        hoax(address(stakingManagerInstance));
        auctionInstance.calculateWinningBid();
    }

    // function test_BidNonWhitelistBiddingWorksCorrectly() public {
    //     bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

    //     hoax(alice);
    //     auctionInstance.bidOnStake{value: 0.1 ether}(proof);

    //     assertEq(auctionInstance.currentHighestBidId(), 1);
    //     assertEq(auctionInstance.numberOfActiveBids(), 1);

    //     (
    //         ,
    //         uint256 amount,
    //         uint256 ipfsIndex,
    //         ,
    //         ,
    //         ,
    //         address bidderAddress,

    //     ) = auctionInstance.bids(1);

    //     assertEq(amount, 0.1 ether);
    //     assertEq(bidderAddress, address(alice));
    //     assertEq(auctionInstance.numberOfBids(), 2);
    //     assertEq(ipfsIndex, 0);

    //     vm.expectRevert("Invalid bid");
    //     hoax(bob);
    //     auctionInstance.bidOnStake{value: 0.001 ether}(proof);

    //     hoax(bob);
    //     auctionInstance.bidOnStake{value: 0.3 ether}(proof);
    //     assertEq(auctionInstance.numberOfActiveBids(), 2);

    //     (, uint256 amount2, , , , , address bidderAddress2, ) = auctionInstance
    //         .bids(auctionInstance.currentHighestBidId());

    //     assertEq(auctionInstance.currentHighestBidId(), 2);
    //     assertEq(amount2, 0.3 ether);
    //     assertEq(bidderAddress2, address(bob));
    //     assertEq(auctionInstance.numberOfBids(), 3);

    //     assertEq(address(auctionInstance).balance, 0.4 ether);
    // }

    // function test_BidWhitelistBiddingWorksCorrectly() public {
    //     bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
    //     bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 1);

    //     hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    //     auctionInstance.bidOnStake{value: 0.001 ether}(proof);

    //     assertEq(auctionInstance.currentHighestBidId(), 1);
    //     assertEq(auctionInstance.numberOfActiveBids(), 1);

    //     (
    //         ,
    //         uint256 amount,
    //         uint256 ipfsIndex,
    //         ,
    //         ,
    //         ,
    //         address bidderAddress,

    //     ) = auctionInstance.bids(1);

    //     assertEq(amount, 0.001 ether);
    //     assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    //     assertEq(address(auctionInstance).balance, 0.001 ether);
    //     assertEq(ipfsIndex, 0);

    //     vm.expectRevert("Invalid bid");
    //     hoax(alice);
    //     auctionInstance.bidOnStake{value: 0.001 ether}(proof);

    //     vm.expectRevert("Invalid bid");
    //     hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     auctionInstance.bidOnStake{value: 0.00001 ether}(proof2);

    //     vm.expectRevert("Invalid bid");
    //     hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     auctionInstance.bidOnStake{value: 6 ether}(proof2);

    //     hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     auctionInstance.bidOnStake{value: 0.002 ether}(proof2);

    //     (, , ipfsIndex, , , , , ) = auctionInstance.bids(1);
    //     assertEq(ipfsIndex, 0);

    //     assertEq(auctionInstance.currentHighestBidId(), 2);
    //     assertEq(auctionInstance.numberOfActiveBids(), 2);

    //     (, amount, , , , , bidderAddress, ) = auctionInstance.bids(2);

    //     assertEq(amount, 0.002 ether);
    //     assertEq(bidderAddress, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    //     assertEq(address(auctionInstance).balance, 0.003 ether);

    //     hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    //     auctionInstance.bidOnStake{value: 0.002 ether}(proof);

    //     (, , ipfsIndex, , , , , ) = auctionInstance.bids(3);
    //     assertEq(ipfsIndex, 1);
    // }

    // function test_BidFailsWhenInvaliAmountSent() public {
    //     bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

    //     vm.expectRevert("Invalid bid");
    //     hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    //     auctionInstance.bidOnStake{value: 0}(proof);

    //     assertEq(auctionInstance.numberOfActiveBids(), 0);

    //     vm.expectRevert("Invalid bid");
    //     hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    //     auctionInstance.bidOnStake{value: 5.01 ether}(proof);

    //     assertEq(auctionInstance.numberOfActiveBids(), 0);
    // }

    function test_PausableBidOnStake() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        assertFalse(auctionInstance.paused());
        vm.prank(owner);
        auctionInstance.pauseContract();
        assertTrue(auctionInstance.paused());

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_CancelBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(1);
    }

    function test_CancelBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        uint256 balanceBeforeCancellation = 0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
                .balance;
        auctionInstance.cancelBid(3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , , bool isActive, , , ) = auctionInstance.bids(3);

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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        assertEq(auctionInstance.currentHighestBidId(), 2);

        vm.stopPrank();
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , , bool isActive, , , ) = auctionInstance.bids(2);

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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        assertEq(auctionInstance.numberOfActiveBids(), 3);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);

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
            3
        );

        assertEq(auctionInstance.merkleRoot(), newRoot);

        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.bidOnStake{value: 0.01 ether}(proofForAddress4);
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

        root = merkle.getRoot(whiteListedAddresses);
    }
}
