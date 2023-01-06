// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract DepositTest is Test {
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

    function testDepositContractInstantiatedCorrectly() public {
        assertEq(depositInstance.stakeAmount(), 0.1 ether);
        assertEq(depositInstance.owner(), address(owner));
    }

    function testDepositCreatesNFTs() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
    }

    function testDepositCreatesNFTsWithCorrectOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
    }

    function testDepositReceivesEther() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(address(depositInstance).balance, 0.1 ether);
    }

    function testDepositUpdatesBalancesMapping() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.1 ether
        );
        vm.stopPrank();
        hoax(address(depositInstance));
        auctionInstance.enableBidding();
        vm.stopPrank();
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.2 ether
        );
    }

    function testDepositDisablesBidding() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.1 ether}();
        assertEq(auctionInstance.bidsEnabled(), false);        
    }

    function testDepositFailsIfIncorrectAmountSent() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        depositInstance.deposit{value: 0.2 ether}();
    }

    function testDepositFailsBidDoesntExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0); 

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.cancelBid(1);
        vm.expectRevert("No bids available at the moment");
        depositInstance.deposit{value: 0.1 ether}();
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(keccak256(abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)));

        root = merkle.getRoot(whiteListedAddresses);
    }
}
