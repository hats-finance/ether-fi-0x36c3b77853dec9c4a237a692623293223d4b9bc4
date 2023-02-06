// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
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
    IDeposit.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

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
        auctionInstance = new Auction(address(treasuryInstance));
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));

        test_data = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        vm.stopPrank();
    }

    function test_AuctionContractInstantiatedCorrectly() public {
        assertEq(auctionInstance.numberOfBids(), 1);
        assertEq(
            auctionInstance.depositContractAddress(),
            address(depositInstance)
        );
    }

    function test_ReEnterAuctionFailsIfAuctionPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        vm.prank(owner);
        auctionInstance.pauseContract();

        depositInstance.deposit{value: 0.032 ether}();
        vm.expectRevert("Pausable: paused");
        depositInstance.cancelStake(0);
    }

    function test_ReEnterAuctionFailsIfNotCorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        depositInstance.deposit{value: 0.032 ether}();
        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);

        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.reEnterAuction(1, withdrawSafeAddress);
    }

    function test_ReEnterAuctionFailsIfBidAlreadyActive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        auctionInstance.bidOnStake{value: 0.05 ether}(proof, "test_pubKey");

        depositInstance.deposit{value: 0.032 ether}();
        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);
        depositInstance.cancelStake(0);
        vm.stopPrank();

        vm.prank(address(depositInstance));
        vm.expectRevert("Bid already active");
        auctionInstance.reEnterAuction(2, withdrawSafeAddress);
    }

    function test_ReEnterAuctionWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        auctionInstance.bidOnStake{value: 0.05 ether}(proof, "test_pubKey");
        assertEq(auctionInstance.currentHighestBidId(), 1);

        depositInstance.deposit{value: 0.032 ether}();
        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);
        assertEq(withdrawSafeAddress.balance, 0.1 ether);
        assertEq(address(auctionInstance).balance, 0.05 ether);
        assertEq(auctionInstance.currentHighestBidId(), 2);

        depositInstance.cancelStake(0);

        (, , , bool isActive, ) = auctionInstance.bids(1);
        assertEq(isActive, true);
        assertEq(withdrawSafeAddress.balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0.15 ether);
        assertEq(auctionInstance.currentHighestBidId(), 1);
    }

    function test_CalculateWinningBidFailsIfNotContractCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        depositInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);
        vm.prank(owner);
        vm.expectRevert("Only deposit contract function");
        auctionInstance.calculateWinningBid(withdrawSafeAddress);
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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );
        assertEq(auctionInstance.currentHighestBidId(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );
        assertEq(auctionInstance.currentHighestBidId(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(
            proofForAddress3,
            "test_pubKey"
        );

        depositInstance.deposit{value: 0.032 ether}();
        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);
        WithdrawSafe withdrawSafeInstance = WithdrawSafe(
            payable(withdrawSafeAddress)
        );
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(withdrawSafeInstance).balance, 0.3 ether);
        assertEq(address(auctionInstance).balance, 0.3 ether);
        vm.stopPrank();

        (, , , bool isActiveBid1, ) = auctionInstance.bids(1);
        (, , , bool isActiveBid2, ) = auctionInstance.bids(2);
        (, , , bool isActiveBid3, ) = auctionInstance.bids(3);

        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(isActiveBid1, true);
        assertEq(isActiveBid2, false);
        assertEq(isActiveBid3, true);

        hoax(address(depositInstance));
        uint256 winner = auctionInstance.calculateWinningBid(
            withdrawSafeAddress
        );

        assertEq(address(withdrawSafeInstance).balance, 0.5 ether);
        assertEq(address(auctionInstance).balance, 0.1 ether);

        (, , , isActiveBid1, ) = auctionInstance.bids(1);
        (, , , isActiveBid3, ) = auctionInstance.bids(3);

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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );

        depositInstance.deposit{value: 0.032 ether}();
        (, address withdrawSafeAddress, , , , , , ) = depositInstance.stakes(0);
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit WinningBidSent(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, 1);
        hoax(address(depositInstance));
        auctionInstance.calculateWinningBid(withdrawSafeAddress);
    }

    function test_BidNonWhitelistBiddingWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(alice);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (uint256 amount, , address bidderAddress, , ) = auctionInstance.bids(1);

        assertEq(amount, 0.1 ether);
        assertEq(bidderAddress, address(alice));
        assertEq(auctionInstance.numberOfBids(), 2);

        vm.expectRevert("Invalid bid");
        hoax(bob);
        auctionInstance.bidOnStake{value: 0.001 ether}(proof, "test_pubKey");

        hoax(bob);
        auctionInstance.bidOnStake{value: 0.3 ether}(proof, "test_pubKey");
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (uint256 amount2, , address bidderAddress2, , ) = auctionInstance.bids(
            auctionInstance.currentHighestBidId()
        );

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(amount2, 0.3 ether);
        assertEq(bidderAddress2, address(bob));
        assertEq(auctionInstance.numberOfBids(), 3);

        assertEq(address(auctionInstance).balance, 0.4 ether);
    }

    function test_BidWhitelistBiddingWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.001 ether}(proof, "test_pubKey");

        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        (uint256 amount, , address bidderAddress, , ) = auctionInstance.bids(1);

        assertEq(amount, 0.001 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(address(auctionInstance).balance, 0.001 ether);

        vm.expectRevert("Invalid bid");
        hoax(alice);
        auctionInstance.bidOnStake{value: 0.001 ether}(proof, "test_pubKey");

        vm.expectRevert("Invalid bid");
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.00001 ether}(proof2, "test_pubKey");

        vm.expectRevert("Invalid bid");
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 6 ether}(proof2, "test_pubKey");

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.002 ether}(proof2, "test_pubKey");

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (amount, , bidderAddress, , ) = auctionInstance.bids(2);

        assertEq(amount, 0.002 ether);
        assertEq(bidderAddress, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        assertEq(address(auctionInstance).balance, 0.003 ether);
    }

    function test_BidFailsWhenInvaliAmountSent() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.expectRevert("Invalid bid");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0}(proof, "test_pubKey");

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.expectRevert("Invalid bid");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 5.01 ether}(proof, "test_pubKey");

        assertEq(auctionInstance.numberOfActiveBids(), 0);
    }

    function test_PausableBidOnStake() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        assertFalse(auctionInstance.paused());
        vm.prank(owner);
        auctionInstance.pauseContract();
        assertTrue(auctionInstance.paused());

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_CancelBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.cancelBid(1);
    }

    function test_CancelBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(
            proofForAddress3,
            "test_pubKey"
        );
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        uint256 balanceBeforeCancellation = 0xCDca97f61d8EE53878cf602FF6BC2f260f10240B
                .balance;
        auctionInstance.cancelBid(3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , bool isActive, ) = auctionInstance.bids(3);

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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(
            proofForAddress3,
            "test_pubKey"
        );
        assertEq(address(auctionInstance).balance, 0.6 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 3);

        assertEq(auctionInstance.currentHighestBidId(), 2);

        vm.stopPrank();
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        (, , , bool isActive, ) = auctionInstance.bids(2);

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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );
        assertEq(auctionInstance.numberOfActiveBids(), 2);

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(
            proofForAddress3,
            "test_pubKey"
        );

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

    function test_IncreaseBidFailsWhenNotExistingBid() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Invalid bid");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function test_IncreaseBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Invalid bid");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function test_IncreaseBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.increaseBid{value: 0.1 ether}(1);
    }

    function test_IncreaseBidFailsIfBidIncreaseToMoreThanMaxBidAmount() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Above max bid");
        auctionInstance.increaseBid{value: 5 ether}(1);
    }

    function test_IncreaseBidWorks() public {
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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress2,
            "test_pubKey"
        );

        startHoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.2 ether}(
            proofForAddress3,
            "test_pubKey"
        );

        assertEq(auctionInstance.currentHighestBidId(), 2);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        auctionInstance.increaseBid{value: 0.2 ether}(3);

        (uint256 amount, , , , ) = auctionInstance.bids(3);

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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.increaseBid{value: 0.2 ether}(1);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.increaseBid{value: 0.2 ether}(1);

        (uint256 amount, , , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);
    }

    function test_DecreaseBidFailsWhenNotBidOwnerCalling() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Invalid bid");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function test_DecreaseBidFailsWhenBidAlreadyInactive() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.cancelBid(1);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid already cancelled");
        auctionInstance.decreaseBid(1, 0.05 ether);
    }

    function test_DecreaseBidFailsWhenAmountToReduceIsToHigh() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Amount too large");
        auctionInstance.decreaseBid(1, 1 ether);
    }

    function test_DecreaseBidFailsIfDecreaseBelowMinBidAmount() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.03 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Bid Below Min Bid");
        auctionInstance.decreaseBid(1, 0.029 ether);
    }

    function test_DecreaseBidWorks() public {
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
        auctionInstance.bidOnStake{value: 0.1 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.6 ether}(
            proofForAddress2,
            "test_pubKey"
        );

        hoax(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress3,
            "test_pubKey"
        );

        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(auctionInstance).balance, 1 ether);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.decreaseBid(2, 0.4 ether);
        console.log(address(auctionInstance).balance);
        (uint256 amount, , , , ) = auctionInstance.bids(2);

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
        auctionInstance.bidOnStake{value: 0.3 ether}(
            proofForAddress1,
            "test_pubKey"
        );

        (uint256 amount, , , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);

        vm.prank(owner);
        auctionInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.decreaseBid(1, 0.1 ether);

        (amount, , , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.3 ether);

        vm.prank(owner);
        auctionInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.decreaseBid(1, 0.1 ether);

        (amount, , , , ) = auctionInstance.bids(1);
        assertEq(amount, 0.2 ether);
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
        auctionInstance.bidOnStake{value: 0.01 ether}(
            proofForAddress4,
            "test_pubKey"
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

        root = merkle.getRoot(whiteListedAddresses);
    }
}
