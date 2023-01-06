// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract SmallScenariosTest is Test {
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
        _merkleSetup();
        treasuryInstance = new Treasury();
        auctionInstance = new Auction(address(treasuryInstance), root);
        depositInstance = new Deposit(address(auctionInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    /**
     *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  One deposit - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     */
    function testScenarioOne() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        assertEq(address(auctionInstance).balance, 0.3 ether);
        assertEq(address(depositInstance).balance, 0);
        
        (uint256 amount,, address bidderAddress, bool isActiveBeforeStake) = auctionInstance.bids(auctionInstance.currentHighestBidId());

        assertEq(auctionInstance.numberOfBids() - 1, 1);
        assertEq(amount, 0.3 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.bidsEnabled(), true);
        assertEq(isActiveBeforeStake, true);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(address(depositInstance).balance, 0.1 ether);
        assertEq(address(auctionInstance).balance, 0);
        assertEq(address(treasuryInstance).balance, 0.3 ether);

        assertEq(auctionInstance.bidsEnabled(), false);

        (,,, bool isActiveAfterStake) = auctionInstance.bids(1);
        assertEq(isActiveAfterStake, false);
    }


    /**
     *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  One cancel - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  Second bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  One updated bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     */
    function testScenarioTwo() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(whiteListedAddresses, 0); 
        bytes32[] memory proofForAddress2 = merkle.getProof(whiteListedAddresses, 1); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.3 ether}(proofForAddress1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        assertEq(address(auctionInstance).balance, 0.3 ether);
        
        (uint256 amount,, address bidderAddress, bool isActiveAfterStake) = auctionInstance.bids(auctionInstance.currentHighestBidId());

        assertEq(auctionInstance.numberOfBids() - 1, 1);
        assertEq(amount, 0.3 ether);
        assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.bidsEnabled(), true);
        assertEq(isActiveAfterStake, true);

        auctionInstance.cancelBid(1);
        assertEq(auctionInstance.numberOfActiveBids(), 0);

        (,,, bool isActiveAfterCancel) = auctionInstance.bids(1);
        assertEq(isActiveAfterCancel, false);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

        auctionInstance.bidOnStake{value: 0.2 ether}(proofForAddress2);
        assertEq(auctionInstance.numberOfBids() - 1, 2);
        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(auctionInstance).balance, 0.2 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 1);

        auctionInstance.updateBid{value: 0.3 ether}(2);
        assertEq(auctionInstance.numberOfBids() - 1, 2);
        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(auctionInstance).balance, 0.5 ether);
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
        root = merkle.getRoot(whiteListedAddresses);
    }
 }
