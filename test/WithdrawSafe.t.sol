// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/interfaces/IWithdrawSafe.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract WithdrawSafeTest is Test {
    IDeposit public depositInterface;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    WithdrawSafe public safeInstance;
    // WithdrawSafeManager public managerInstance;
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

        test_data_2 = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials_2",
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.setTreasuryAddress(address(treasuryInstance));
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(
            0,
            "Validator_key",
            "encrypted_key_password",
            "test_stakerPubKey",
            test_data
        );
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);

        (, address withdrawSafe, , , , , , ) = depositInstance.stakes(0);
        safeInstance = WithdrawSafe(payable(withdrawSafe));
    }

    function test_ReceiveAuctionFundsWorksCorrectly() public {
        assertEq(
            safeInstance.withdrawableBalance(
                0,
                IWithdrawSafe.ValidatorRecipientType.TREASURY
            ),
            10000000000000000
        );
        assertEq(
            safeInstance.withdrawableBalance(
                0,
                IWithdrawSafe.ValidatorRecipientType.OPERATOR
            ),
            10000000000000000
        );
        assertEq(
            safeInstance.withdrawableBalance(
                0,
                IWithdrawSafe.ValidatorRecipientType.BNFTHOLDER
            ),
            20000000000000000
        );
        assertEq(
            safeInstance.withdrawableBalance(
                0,
                IWithdrawSafe.ValidatorRecipientType.TNFTHOLDER
            ),
            60000000000000000
        );
        assertEq(address(safeInstance).balance, 0.1 ether);
        // assertEq(address(managerInstance).balance, 0 ether);
    }

    function test_ReceiveAuctionFundsFailsIfNotAuctionContractCalling() public {
        vm.expectRevert("Only auction contract function");
        safeInstance.receiveAuctionFunds(0, 0.1 ether);
    }

    function test_WithdrawFundsFailsIfNotCorrectCaller() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(safeInstance).call{value: 0.04 ether}("");
        require(sent, "Failed to send Ether");

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Incorrect caller");
        safeInstance.withdrawFunds(0);
    }

    function test_WithdrawFundsWorksCorrectly() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(safeInstance).call{value: 0.04 ether}("");
        require(sent, "Failed to send Ether");
        assertEq(address(safeInstance).balance, 0.14 ether);
        assertEq(address(auctionInstance).balance, 0 ether);

        uint256 stakerBalance = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            .balance;
        uint256 operatorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        safeInstance.withdrawFunds(0);
        assertEq(address(safeInstance).balance, 0 ether);
        assertEq(address(treasuryInstance).balance, 0.01040 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            operatorBalance + 0.0104 ether
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
