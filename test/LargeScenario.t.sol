// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/WithdrawSafe.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../src/interfaces/IDeposit.sol";
import "../lib/murky/src/Merkle.sol";

contract LargeScenariosTest is Test {
    Deposit public depositInstance;
    WithdrawSafe public withdrawSafeInstance;
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
    address stakerPublicKey = vm.addr(3);

    function setUp() public {
        vm.startPrank(owner);
        _merkleSetup();
        treasuryInstance = new Treasury();
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

    /**
     *  Three bids - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf, 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
     *  One bid cancel - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  One deposit - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Attempted Bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Fourth Bid - 0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098
     *  UpdatedBid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  Second deposit - 0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
     *  First deposit cancel - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Second deposit register validator - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Attempted second deposit cancel - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  Second deposit acceptValidator -
     */
    function test_LargeScenario() public {
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
        bytes32[] memory proofForAddress4 = merkle.getProof(
            whiteListedAddresses,
            3
        );

        //Bid One
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proofForAddress1);
        //Check auction contract received funds
        assertEq(address(auctionInstance).balance, 0.1 ether);
        //Check the bid is the current highest
        assertEq(auctionInstance.currentHighestBidId(), 1);
        //Check the number of bids has increased
        assertEq(auctionInstance.numberOfBids() - 1, 1);
        //Check the number of active bids has increased
        assertEq(auctionInstance.numberOfActiveBids(), 1);
        //Check the bid information was captured correctly
        (
            uint256 amountAfterBid1,
            ,
            address bidderAddressForBid1,
            bool isActiveBid1
        ) = auctionInstance.bids(1);
        assertEq(amountAfterBid1, 0.1 ether);
        assertEq(
            bidderAddressForBid1,
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(isActiveBid1, true);

        //Bid Two
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.4 ether}(proofForAddress2);
        //Check auction contract received funds
        assertEq(address(auctionInstance).balance, 0.5 ether);
        //Check the bid is the current highest
        assertEq(auctionInstance.currentHighestBidId(), 2);
        //Check the number of bids has increased
        assertEq(auctionInstance.numberOfBids() - 1, 2);
        //Check the number of active bids has increased
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        //Check the bid information was captured correctly
        (
            uint256 amountAfterBid2,
            ,
            address bidderAddressForBid2,
            bool isActiveBid2
        ) = auctionInstance.bids(2);
        assertEq(amountAfterBid2, 0.4 ether);
        assertEq(
            bidderAddressForBid2,
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(isActiveBid2, true);

        //Bid Three
        hoax(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20);
        auctionInstance.bidOnStake{value: 0.7 ether}(proofForAddress3);
        //Check auction contract received funds
        assertEq(address(auctionInstance).balance, 1.2 ether);
        //Check the bid is the current highest
        assertEq(auctionInstance.currentHighestBidId(), 3);
        //Check the number of bids has increased
        assertEq(auctionInstance.numberOfBids() - 1, 3);
        //Check the number of active bids has increased
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        //Check the bid information was captured correctly
        (
            uint256 amountAfterBid3,
            ,
            address bidderAddressForBid3,
            bool isActiveBid3
        ) = auctionInstance.bids(3);
        assertEq(amountAfterBid3, 0.7 ether);
        assertEq(
            bidderAddressForBid3,
            0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
        );
        assertEq(isActiveBid3, true);

        //Bid cancelled
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.cancelBid(2);
        //Check auction contract received funds
        assertEq(address(auctionInstance).balance, 0.8 ether);
        //Check the bid is the current highest
        assertEq(auctionInstance.currentHighestBidId(), 3);
        //Check the number of bids has increased
        assertEq(auctionInstance.numberOfBids() - 1, 3);
        //Check the number of active bids has increased
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        //Check the bid has been de-activated
        (, , , bool isActiveAfterCancel) = auctionInstance.bids(2);
        assertEq(isActiveAfterCancel, false);

        //Deposit One
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
        assertEq(address(treasuryInstance).balance, 0.7 ether);
        assertEq(address(auctionInstance).balance, 0.1 ether);
        assertEq(address(depositInstance).balance, 0.032 ether);
        vm.stopPrank();

        //Bid Four
        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.bidOnStake{value: 0.4 ether}(proofForAddress4);
        //Check auction contract received funds
        assertEq(address(auctionInstance).balance, 0.5 ether);
        //Check the bid is the current highest
        assertEq(auctionInstance.currentHighestBidId(), 4);
        //Check the number of bids has increased
        assertEq(auctionInstance.numberOfBids() - 1, 4);
        //Check the number of active bids has increased
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        //Check the bid information was captured correctly
        (
            uint256 amountAfterBid4,
            ,
            address bidderAddressForBid4,
            bool isActiveBid4
        ) = auctionInstance.bids(4);
        assertEq(amountAfterBid4, 0.4 ether);
        assertEq(
            bidderAddressForBid4,
            0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098
        );
        assertEq(isActiveBid4, true);

        //Bid updated
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.increaseBid{value: 0.9 ether}(1);
        assertEq(auctionInstance.currentHighestBidId(), 1);
        assertEq(address(auctionInstance).balance, 1.4 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        //Check the bid information was captured correctly
        (
            uint256 amountForUpdatedBid1,
            ,
            address bidderAddressForUpdatedBid1,
            bool isActiveAfterUpdatedBid1
        ) = auctionInstance.bids(1);
        assertEq(amountForUpdatedBid1, 1 ether);
        assertEq(
            bidderAddressForUpdatedBid1,
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(isActiveAfterUpdatedBid1, true);

        //Deposit Two
        hoax(0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f);
        depositInstance.deposit{value: 0.032 ether}();

        assertEq(auctionInstance.currentHighestBidId(), 4);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
        assertEq(address(treasuryInstance).balance, 1.7 ether);
        assertEq(address(auctionInstance).balance, 0.4 ether);
        assertEq(address(depositInstance).balance, 0.064 ether);

        //Deposit One cancelled
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.cancelStake(0);

        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(auctionInstance.numberOfBids() - 1, 4);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(address(treasuryInstance).balance, 1 ether);
        assertEq(address(auctionInstance).balance, 1.1 ether);
        assertEq(address(depositInstance).balance, 0.032 ether);

        //Deposit Two register validator
        hoax(0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f);
        depositInstance.registerValidator(
            1,
            "Encrypted_Key",
            "encrypted_key_password",
            stakerPublicKey,
            test_data
        );

        (
            uint256 validatorId,
            uint256 bidId,
            uint256 stakeId,
            bytes memory validatorKey,
            bytes memory encryptedValidatorKeyPassword,

        ) = depositInstance.validators(0);
        assertEq(validatorId, 0);
        assertEq(bidId, 1);
        assertEq(stakeId, 1);
        assertEq(validatorKey, "Encrypted_Key");
        assertEq(encryptedValidatorKeyPassword, "encrypted_key_password");

        //Attempt deposit two cancel
        hoax(0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f);
        vm.expectRevert("Cancelling availability closed");
        depositInstance.cancelStake(1);

        //Deposit two operator accepting validator
        hoax(0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f);
        vm.expectRevert("Incorrect caller");
        depositInstance.acceptValidator(0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
            ),
            1
        );

        (, address withdrawSafe, , , , , , ) = depositInstance.stakes(1);
        withdrawSafeInstance = WithdrawSafe(withdrawSafe);
        assertEq(
            withdrawSafeInstance.owner(),
            0x835ff0CC6F35B148b85e0E289DAeA0497ec5aA7f
        );
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
                abi.encodePacked(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        root = merkle.getRoot(whiteListedAddresses);
    }
}
