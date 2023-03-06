// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorKeyManager.sol";
import "forge-std/console.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/Deposit.sol";
import "src/WithdrawSafeManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract NodeOperatorKeyManagerTest is Test {
    event OperatorRegistered(
        uint128 totalKeys,
        uint128 keysUsed,
        string ipfsHash
    );

    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    Deposit public depositInstance;
    WithdrawSafe public withdrawSafeInstance;
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

    string aliceIPFSHash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new Auction(address(nodeOperatorKeyManagerInstance));
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        managerInstance = new WithdrawSafeManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(depositInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        auctionInstance.setManagerAddress(address(managerInstance));
        depositInstance.setManagerAddress(address(managerInstance));

        test_data = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        vm.stopPrank();
    }

    function test_RegisterNodeOperator() public {
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceIPFSHash,
            uint128(10)
        );
        (
            uint128 totalKeys,
            uint128 keysUsed,
            string memory aliceHash
        ) = nodeOperatorKeyManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, aliceIPFSHash);
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);
    }

    function test_EventOperatorRegistered() public {
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(10, 0, aliceIPFSHash);
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);
    }

    function test_IncreaseKeysIndex() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        uint256 aliceKeysUsed = nodeOperatorKeyManagerInstance
            .getNumberOfKeysUsed(alice);

        assertEq(aliceKeysUsed, 0);

        hoax(alice);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        aliceKeysUsed = nodeOperatorKeyManagerInstance.getNumberOfKeysUsed(
            alice
        );

        assertEq(aliceKeysUsed, 1);
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
