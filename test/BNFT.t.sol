// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/WithdrawSafeFactory.sol";
import "../src/WithdrawSafeManager.sol";

import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract BNFTTest is Test {
    Deposit public depositInstance;
    WithdrawSafe public withdrawSafeInstance;
    WithdrawSafeFactory public factoryInstance;
    WithdrawSafeManager public managerInstance;
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
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        // managerInstance = new WithdrawSafeManager(
        //     address(treasuryInstance),
        //     address(auctionInstance),
        //     address(depositInstance),
        //     address(TestTNFTInstance),
        //     address(TestBNFTInstance)
        // );

        // auctionInstance.setManagerAddress(address(managerInstance));
        // depositInstance.setManagerAddress(address(managerInstance));

        test_data = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        vm.stopPrank();
    }

    function test_BNFTContractGetsInstantiatedCorrectly() public {
        assertEq(
            TestBNFTInstance.depositContractAddress(),
            address(depositInstance)
        );
        assertEq(TestBNFTInstance.nftValue(), 0.002 ether);
    }

    function test_BNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only deposit contract function");
        TestBNFTInstance.mint(address(alice), 1);
    }

    function test_BNFTCannotBeTransferred() public {
        IDeposit.DepositData memory test_data = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof, "test_pubKey");
        depositInstance.deposit{value: 0.032 ether}();
        vm.expectRevert("Err: token is SOUL BOUND");
        TestBNFTInstance.transferFrom(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            address(alice),
            0
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
