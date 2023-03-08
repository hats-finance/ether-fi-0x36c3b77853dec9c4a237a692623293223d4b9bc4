// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorKeyManager.sol";
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

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        treasuryInstance.setAuctionManagerContractAddress(
            address(auctionInstance)
        );
        auctionInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        auctionInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        test_data = IStakingManager.DepositData({
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
            uint64(10)
        );
        (
            uint64 totalKeys,
            uint64 keysUsed,
            bytes32 aliceHash
        ) = nodeOperatorKeyManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, keccak256(abi.encodePacked(aliceIPFSHash)));
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
