// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract AuctionTest is Test {
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        auctionInstance = new Auction(address(treasuryInstance));
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testAuctionContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfBids(), 1);
        assertEq(
            auctionInstance.depositContractAddress(),
            address(depositInstance)
        );
    }

    function testEnablingBiddingFailsIfBiddingAlreadyEnabled() public {
        hoax(address(depositInstance));
        vm.expectRevert("Bids already enabled");
        auctionInstance.enableBidding();
    }

    // function testEnablingBiddingFailsIfNotContractCalling() public {
    //     vm.prank(owner);
    //     vm.expectRevert("Only deposit contract function");
    //     auctionInstance.enableBidding();
    // }

    function testEnablingBiddingWorks() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        console.log(address(depositInstance).balance);
        assertEq(auctionInstance.bidsEnabled(), true);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        assertEq(auctionInstance.bidsEnabled(), false);

        hoax(address(depositInstance));
        auctionInstance.enableBidding();

        assertEq(auctionInstance.bidsEnabled(), true);
    }

    function testDisablingBiddingFailsIfNotContractCalling() public {
        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.disableBidding();
    }

    function testDisablingBiddingWorks() public {
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

        assertEq(auctionInstance.bidsEnabled(), true);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        assertEq(auctionInstance.currentHighestBidId(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        assertEq(address(treasuryInstance).balance, 0);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        hoax(address(depositInstance));
        address winner = auctionInstance.disableBidding();
        assertEq(address(treasuryInstance).balance, 0.3 ether);
        assertEq(address(auctionInstance).balance, 0.3 ether);

        (, , , bool isActiveBid1) = auctionInstance.bids(1);
        (, , , bool isActiveBid2) = auctionInstance.bids(2);
        (, , , bool isActiveBid3) = auctionInstance.bids(3);

        assertEq(auctionInstance.bidsEnabled(), false);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid2, false);
        assertEq(isActiveBid3, true);
        assertEq(winner, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
    }

    function testBiddingFailsWhenBidsDisabled() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bidding is on hold");
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
    }

    function testBiddingWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (uint256 amount, , address bidderAddress, ) = auctionInstance.bids(1);

        assertEq(amount, 0.1 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.numberOfBids(), 2);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}(proof);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (uint256 amount2, , address bidderAddress2, ) = auctionInstance.bids(
            auctionInstance.currentHighestBidId()
        );

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(amount2, 0.3 ether);
        assertEq(bidderAddress2, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.numberOfBids(), 3);

        assertEq(address(auctionInstance).balance, 0.4 ether);
    }

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

    function testCancelBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(1);
    }

    function testCancelBidFailsWhenBiddingIsInactive() public {
        bytes32[] memory proofAddressOne = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofAddressTwo = merkle.getProof(
            whiteListedAddresses,
            1
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofAddressOne);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofAddressTwo);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Cancelling bids on hold");
        auctionInstance.cancelBid(1);
    }

    function testCancelBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);
    }

    function testCancelBidFailsWhenNotExistingBid() public {
        vm.prank(alice);
        vm.expectRevert("Invalid bid");
        auctionInstance.cancelBid(1);
    }

    function testCancelBidWorksIfBidIsNotCurrentHighest() public {
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

        (, , , bool isActive) = auctionInstance.bids(3);

        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(
            0xCDca97f61d8EE53878cf602FF6BC2f260f10240B.balance,
            balanceBeforeCancellation += 0.2 ether
        );
    }

    function testCancelBidWorksIfBidIsCurrentHighest() public {
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

        (, , , bool isActive) = auctionInstance.bids(2);

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

    function testIncreaseBidFailsWhenNotExistingBid() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Invalid bid");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function testIncreaseBidFailsWhenBiddingIsInactive() public {
        bytes32[] memory proofAddressOne = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofAddressTwo = merkle.getProof(
            whiteListedAddresses,
            1
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofAddressOne);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofAddressTwo);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Increase bidding on hold");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function testIncreaseBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Invalid bid");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function testIncreaseBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function testIncreaseBidWorks() public {
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

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress3);

        assertEq(auctionInstance.currentHighestBidId(), 2);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        auctionInstance.increaseBid{value: 0.2 ether}(3);

        (uint256 amount, , , ) = auctionInstance.bids(3);

        assertEq(amount, 0.4 ether);
        assertEq(address(auctionInstance).balance, 0.8 ether);
        assertEq(auctionInstance.currentHighestBidId(), 3);
    }

    function test_PausableIncreaseBid() public {
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

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.increaseBid{value: 0.2 ether}(1);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.increaseBid{value: 0.2 ether}(1);

        (uint256 amount, , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);
    }

    function testDecreaseBidFailsWhenNotExistingBid() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Invalid bid");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function testDecreaseBidFailsWhenBiddingIsInactive() public {
        bytes32[] memory proofAddressOne = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofAddressTwo = merkle.getProof(
            whiteListedAddresses,
            1
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofAddressOne);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.2 ether}(proofAddressTwo);

        hoax(address(depositInstance));
        auctionInstance.disableBidding();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Decrease bidding on hold");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function testDecreaseBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Invalid bid");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function testDecreaseBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function testDecreaseBidFailsWhenAmountToReduceIsToHigh() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Amount to large");
        auctionInstance.decreaseBid(1, 1 ether);
    }

    function testDecreaseBidWorks() public {
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

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.6 ether}(proofForAddress2);

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress3);

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(auctionInstance).balance, 1 ether);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.decreaseBid(2, 0.4 ether);
        console.log(address(auctionInstance).balance);
        (uint256 amount, , , ) = auctionInstance.bids(2);

        assertEq(amount, 0.2 ether);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);
    }

    function test_PausableDecreaseBid() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofForAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress1);

        (uint256 amount, , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.decreaseBid(1, 0.1 ether);

        (amount, , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.decreaseBid(1, 0.1 ether);

        (amount, , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.2 ether);
    }

    function testUpdatingMerkleFailsIfNotOwner() public {
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

    function testUpdatingMerkle() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        assertEq(auctionInstance.merkleRoot(), root);

        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        vm.expectRevert("Invalid merkle proof");
        auctionInstance.bidOnStake(proofForAddress1);

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
        auctionInstance.bidOnStake(proofForAddress4);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
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
