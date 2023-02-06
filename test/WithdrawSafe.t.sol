// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/interfaces/IWithdrawSafe.sol";
import "../src/WithdrawSafe.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract DepositTest is Test {
    IDeposit public depositInterface;
    WithdrawSafe public withdrawSafeInstance;
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
    address stakerPubKey = vm.addr(3);

    function setUp() public {
        vm.startPrank(owner);
        _merkleSetup();
        treasuryInstance = new Treasury();
        auctionInstance = new Auction(address(treasuryInstance));
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance), address(treasuryInstance));
        depositInterface = IDeposit(address(depositInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        withdrawSafeInstance = new WithdrawSafe(address(treasuryInstance), address(auctionInstance), address(depositInstance));
        depositInstance.setUpWithdrawContract(address(withdrawSafeInstance));

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

    function test_WithdrawSafeContractInstantiatedCorrectly() public {
        assertEq(withdrawSafeInstance.owner(), owner);
        assertEq(withdrawSafeInstance.treasuryContract(), address(treasuryInstance));
        assertEq(withdrawSafeInstance.auctionContract(), address(auctionInstance));
        assertEq(withdrawSafeInstance.depositContract(), address(depositInstance));

        (
            uint256 treasurySplit, 
            uint256 nodeOperatorSplit, 
            uint256 tnftHolderSplit, 
            uint256 bnftHolderSplit
        ) = withdrawSafeInstance.auctionContractRevenueSplit();

        assertEq(treasurySplit, 5);
        assertEq(nodeOperatorSplit, 5);
        assertEq(tnftHolderSplit, 81);
        assertEq(bnftHolderSplit, 9);

        (
            treasurySplit, 
            nodeOperatorSplit, 
            tnftHolderSplit, 
            bnftHolderSplit
        ) = withdrawSafeInstance.validatorExitRevenueSplit();

        assertEq(treasurySplit, 5);
        assertEq(nodeOperatorSplit, 5);
        assertEq(tnftHolderSplit, 81);
        assertEq(bnftHolderSplit, 9);
    }

    function test_SetUpValidatorFailsIfNotDepositContractCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            stakerPubKey,
            test_data
        );
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);
        vm.expectRevert("Only deposit contract function");
        withdrawSafeInstance.setUpValidatorData(0, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    }

    function test_SetUpValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            stakerPubKey,
            test_data
        );
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);

        (address tnftHolder, address bnftHolder, address operator) = withdrawSafeInstance.recipientsPerValidator(0);
        assertEq(tnftHolder, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        assertEq(bnftHolder, 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        assertEq(operator, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
    }

    function test_ReceiveAuctionFundsWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            stakerPubKey,
            test_data
        );
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);

        hoax(address(auctionInstance));
        withdrawSafeInstance.receiveAuctionFunds{value: 0.1 ether}(0);

        assertEq(withdrawSafeInstance.claimableBalance(0, IWithdrawSafe.ValidatorRecipientType.TREASURY), 5000000000000000);
        assertEq(withdrawSafeInstance.claimableBalance(0, IWithdrawSafe.ValidatorRecipientType.OPERATOR), 5000000000000000);
        assertEq(withdrawSafeInstance.claimableBalance(0, IWithdrawSafe.ValidatorRecipientType.BNFTHOLDER), 9000000000000000);
        assertEq(withdrawSafeInstance.claimableBalance(0, IWithdrawSafe.ValidatorRecipientType.TNFTHOLDER), 81000000000000000);
    }

    function test_ReceiveAuctionFundsFailsIfNotAuctionContractCalling() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            stakerPubKey,
            test_data
        );
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);
        vm.expectRevert("Only auction contract function");
        withdrawSafeInstance.receiveAuctionFunds{value: 0.1 ether}(0);
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