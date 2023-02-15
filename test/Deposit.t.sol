// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/WithdrawSafeManager.sol";
import "../src/WithdrawSafeFactory.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract DepositTest is Test {
    IDeposit public depositInterface;
    WithdrawSafe public withdrawSafeInstance;
    WithdrawSafeFactory public factoryInstance;
    WithdrawSafeManager public managerInstance;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IDeposit.DepositData public test_data;
    IDeposit.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        auctionInstance = new Auction();
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        factoryInstance = new WithdrawSafeFactory();
        depositInstance = new Deposit(
            address(auctionInstance),
            address(factoryInstance)
        );
        depositInstance.setTreasuryAddress(address(treasuryInstance));
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

        test_data_2 = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials_2",
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2"
        });

        vm.stopPrank();
    }

    function test_DepositContractInstantiatedCorrectly() public {
        assertEq(depositInstance.stakeAmount(), 0.032 ether);
        assertEq(depositInstance.owner(), owner);
    }

    function test_DepositCorrectlyInstantiatesStakeObject() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "encrypted_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );

        (
            address staker,
            ,
            bytes memory stakerPublicKey,
            IDeposit.DepositData memory deposit_data,
            uint256 amount,
            uint256 winningBid,
            uint256 stakeId,

        ) = depositInstance.stakes(0);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(amount, 0.032 ether);
        assertEq(winningBid, 1);
        assertEq(stakeId, 0);
        assertEq(stakerPublicKey, "test_stakerPubKey");

        assertEq(
            deposit_data.operator,
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(deposit_data.withdrawalCredentials, "test_credentials");
        assertEq(deposit_data.depositDataRoot, "test_deposit_root");
        assertEq(deposit_data.publicKey, "test_pubkey");
        assertEq(deposit_data.signature, "test_signature");
    }

    function test_DepositReceivesEther() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(address(depositInstance).balance, 0.032 ether);
    }

    function test_DepositUpdatesBalancesMapping() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.032 ether
        );

        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.064 ether
        );
    }

    function test_DepositFailsIfIncorrectAmountSent() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        depositInstance.deposit{value: 0.2 ether}();
    }

    function test_DepositFailsBidDoesntExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        auctionInstance.cancelBid(1);
        vm.expectRevert("No bids available at the moment");
        depositInstance.deposit{value: 0.032 ether}();
    }

    function test_DepositfailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(owner);
        depositInstance.pauseContract();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        vm.expectRevert("Pausable: paused");
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(depositInstance.paused(), true);
        vm.stopPrank();

        vm.prank(owner);
        depositInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(depositInstance.paused(), false);
        assertEq(address(depositInstance).balance, 0.032 ether);
    }

    function test_EtherFailSafeWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 walletBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        assertEq(address(depositInstance).balance, 0.032 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.132 ether
        );
        vm.stopPrank();

        vm.prank(owner);
        uint256 walletBalance2 = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        depositInstance.fetchEtherFromContract(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(address(depositInstance).balance, 0 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.1 ether
        );
    }

    function test_RegisterValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Incorrect caller");
        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
    }

    function test_RegisterValidatorFailsIfStakeNotInCorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.cancelStake(0);

        vm.expectRevert("Stake not in correct phase");
        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();

        vm.prank(owner);
        depositInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();

        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );

        (
            ,
            uint256 bidId,
            uint256 stakeId,
            bytes memory validatorKey,
            bytes memory encryptedValidatorKeyPassword,

        ) = depositInstance.validators(0);
        assertEq(bidId, 1);
        assertEq(stakeId, 0);
        assertEq(validatorKey, "validator_key");
        assertEq(depositInstance.numberOfValidators(), 1);
        assertEq(encryptedValidatorKeyPassword, "encrypted_key_password");
    }

    function test_AcceptValidatorFailsIfPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        vm.stopPrank();

        vm.prank(owner);
        depositInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        depositInstance.acceptValidator(0);
    }

    function test_AcceptValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Incorrect caller");
        depositInstance.acceptValidator(0);
    }

    function test_AcceptValidatorFailsIfValidatorNotInCorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        depositInstance.acceptValidator(0);

        vm.expectRevert("Validator not in correct phase");
        depositInstance.acceptValidator(0);
    }

    function test_AcceptValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();

        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );

        assertEq(address(auctionInstance).balance, 0.1 ether);
        depositInstance.acceptValidator(0);

        (
            ,
            address withdrawSafeAddress,
            ,
            ,
            ,
            uint256 winningBidId,
            ,

        ) = depositInstance.stakes(0);

        assertEq(withdrawSafeAddress.balance, 0.1 ether);
        assertEq(address(managerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0);

        address operatorAddress = managerInstance.operatorAddresses(0);
        assertEq(operatorAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        address safeAddress = managerInstance.withdrawSafeAddressesPerValidator(
            0
        );
        assertEq(safeAddress, withdrawSafeAddress);

        assertEq(
            TestBNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
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

    function test_CancelStakeFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        depositInstance.deposit{value: 0.032 ether}();
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert("Not bid owner");
        depositInstance.cancelStake(0);
    }

    function test_CancelStakeFailsIfCancellingAvailabilityClosed() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.cancelStake(0);

        vm.expectRevert("Cancelling availability closed");
        depositInstance.cancelStake(0);
    }

    function test_CancelStakeWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        auctionInstance.bidOnStake{value: 0.3 ether}(proof, "test_pubKey");
        auctionInstance.bidOnStake{value: 0.2 ether}(proof, "test_pubKey");

        assertEq(address(auctionInstance).balance, 0.6 ether);

        depositInstance.deposit{value: 0.032 ether}();
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        (
            address staker,
            ,
            ,
            ,
            uint256 amount,
            uint256 winningbidID,
            ,

        ) = depositInstance.stakes(0);
        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(amount, 0.032 ether);
        assertEq(winningbidID, 2);

        (uint256 bidAmount, , address bidder, bool isActive, ) = auctionInstance
            .bids(winningbidID);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        depositInstance.cancelStake(0);
        (, , , , , winningbidID, , ) = depositInstance.stakes(0);
        assertEq(winningbidID, 0);

        (bidAmount, , bidder, isActive, ) = auctionInstance.bids(2);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            depositorBalance + 0.032 ether
        );
    }

    function test_CorrectValidatorAttatchedToNft() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        depositInstance.acceptValidator(0);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            1,
            "Validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        depositInstance.acceptValidator(1);

        assertEq(TestBNFTInstance.validatorToId(0), 0);
        assertEq(TestBNFTInstance.validatorToId(1), 1);
        assertEq(
            TestBNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(0),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(1),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(1),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
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
        assertEq(
            TestBNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
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
                abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)
            )
        );

        root = merkle.getRoot(whiteListedAddresses);
    }
}
