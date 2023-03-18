// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/StakingManager.sol";
import "forge-std/console.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IDepositContract.sol";
import "src/EtherFiNodesManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract NodeOperatorKeyManagerTest is Test {
    event OperatorRegistered(
        uint64 totalKeys,
        uint64 keysUsed,
        string ipfsHash
    );

    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    StakingManager public stakingManagerInstance;
    EtherFiNode public etherFiNodeInstance;
    EtherFiNodesManager public managerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    string aliceIPFSHash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";
    string _ipfsHash = "ipfsHash";

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        nodeOperatorKeyManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorKeyManagerInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        vm.stopPrank();
    }

    function test_RegisterNodeOperator() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            uint64(10)
        );
        (
            uint64 totalKeys,
            uint64 keysUsed,
            bytes memory aliceHash
        ) = nodeOperatorKeyManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, abi.encodePacked(aliceIPFSHash));
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);
    }

    function test_EventOperatorRegistered() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(10, 0, aliceIPFSHash);
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            10
        );
    }

    function test_FetchNextKeyIndex() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            uint64(10)
        );

        (, uint64 keysUsed, ) = nodeOperatorKeyManagerInstance
            .addressToOperatorData(alice);

        assertEq(keysUsed, 0);

        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        (, keysUsed, ) = nodeOperatorKeyManagerInstance.addressToOperatorData(
            alice
        );

        assertEq(keysUsed, 1);
    }

    function test_UpdatingMerkle() public {
        assertEq(nodeOperatorKeyManagerInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        vm.prank(owner);
        nodeOperatorKeyManagerInstance.updateMerkleRoot(newRoot);

        bytes32[] memory proofForAddress4 = merkle.getProof(
            whiteListedAddresses,
            5
        );

        assertEq(nodeOperatorKeyManagerInstance.merkleRoot(), newRoot);

        vm.prank(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        nodeOperatorKeyManagerInstance.registerNodeOperator(
            proofForAddress4,
            _ipfsHash,
            5
        );

        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.createBid{value: 0.01 ether}(1, 0.01 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_UpdatingMerkleFailsIfNotOwner() public {
        assertEq(nodeOperatorKeyManagerInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nodeOperatorKeyManagerInstance.updateMerkleRoot(newRoot);
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));

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
