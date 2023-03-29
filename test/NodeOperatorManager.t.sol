// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorManager.sol";
import "../src/StakingManager.sol";
import "forge-std/console.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IDepositContract.sol";
import "src/EtherFiNodesManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract NodeOperatorManagerTest is Test {
    event OperatorRegistered(uint64 totalKeys, uint64 keysUsed, bytes ipfsHash);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);

    NodeOperatorManager public nodeOperatorManagerInstance;
    StakingManager public stakingManagerInstance;
    EtherFiNode public etherFiNodeInstance;
    EtherFiNodesManager public managerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    bytes aliceIPFSHash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";
    bytes _ipfsHash = "ipfsHash";
    bytes32 salt = 0x1234567890123456789012345678901234567890123456789012345678901234;

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorManagerInstance = new NodeOperatorManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorManagerInstance)
        );
        nodeOperatorManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInterfaceInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInterfaceInstance()));
        protocolRevenueManagerInstance = new ProtocolRevenueManager{salt:salt}();
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );
        EtherFiNode etherFiNode = new EtherFiNode();

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        stakingManagerInstance.registerEtherFiNodeImplementationContract(address(etherFiNode));
        stakingManagerInstance.setProtocolRevenueManagerAddress(address(protocolRevenueManagerInstance));

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });


        assertEq(nodeOperatorManagerInstance.auctionManagerContractAddress(), address(auctionInstance));
    
        vm.stopPrank();
    }

    function test_RegisterNodeOperator() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.startPrank(alice);
        assertEq(nodeOperatorManagerInstance.registered(alice), false);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            uint64(10)
        );
        (
            uint64 totalKeys,
            uint64 keysUsed,
            bytes memory aliceHash
        ) = nodeOperatorManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, abi.encodePacked(aliceIPFSHash));
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);

        assertEq(nodeOperatorManagerInstance.registered(alice), true);

        vm.expectRevert("Already registered");
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            uint64(10)
        );
    }

    function test_EventOperatorRegistered() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(10, 0, aliceIPFSHash);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            10
        );
    }

    function test_FetchNextKeyIndex() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 1);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFSHash,
            uint64(10)
        );

        (, uint64 keysUsed, ) = nodeOperatorManagerInstance
            .addressToOperatorData(alice);

        assertEq(keysUsed, 0);

        hoax(alice);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        (, keysUsed, ) = nodeOperatorManagerInstance.addressToOperatorData(
            alice
        );

        assertEq(keysUsed, 1);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFSHash,
            1
        );
        vm.expectRevert("Insufficient public keys");
        auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);
        vm.stopPrank();

        vm.expectRevert("Only auction manager contract function");
        vm.prank(alice);
        nodeOperatorManagerInstance.fetchNextKeyIndex(alice);
    }

    function test_UpdatingMerkle() public {
        assertEq(nodeOperatorManagerInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        
        vm.prank(owner);
        nodeOperatorManagerInstance.updateMerkleRoot(newRoot);

        bytes32[] memory proofForAddress4 = merkle.getProof(
            whiteListedAddresses,
            4
        );

        assertEq(nodeOperatorManagerInstance.merkleRoot(), newRoot);

        vm.prank(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofForAddress4,
            _ipfsHash,
            5
        );

        hoax(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098);
        auctionInstance.createBid{value: 0.01 ether}(1, 0.01 ether);
        assertEq(auctionInstance.numberOfActiveBids(), 1);
    }

    function test_UpdatingMerkleFailsIfNotOwner() public {
        assertEq(nodeOperatorManagerInstance.merkleRoot(), root);

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x48809A2e8D921790C0B8b977Bbb58c5DbfC7f098)
            )
        );

        bytes32 newRoot = merkle.getRoot(whiteListedAddresses);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        nodeOperatorManagerInstance.updateMerkleRoot(newRoot);
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
