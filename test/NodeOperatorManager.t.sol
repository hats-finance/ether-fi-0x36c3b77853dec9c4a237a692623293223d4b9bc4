// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract NodeOperatorManagerTest is TestSetup {
    event OperatorRegistered(uint64 totalKeys, uint64 keysUsed, bytes ipfsHash);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);

    bytes aliceIPFS_Hash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";

    function setUp() public {
        setUpTests();
    }

    function test_RegisterNodeOperator() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.startPrank(alice);
        assertEq(nodeOperatorManagerInstance.registered(alice), false);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFS_Hash,
            uint64(10)
        );
        (
            uint64 totalKeys,
            uint64 keysUsed,
            bytes memory aliceHash
        ) = nodeOperatorManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, abi.encodePacked(aliceIPFS_Hash));
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);

        assertEq(nodeOperatorManagerInstance.registered(alice), true);

        vm.expectRevert("Already registered");
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFS_Hash,
            uint64(10)
        );
    }

    function test_EventOperatorRegistered() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(10, 0, aliceIPFS_Hash);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            aliceIPFS_Hash,
            10
        );
    }

    function test_FetchNextKeyIndex() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            aliceIPFS_Hash,
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
            aliceIPFS_Hash,
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
            10
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

    function test_CanOnlySetAddressesOnce() public {
         vm.startPrank(owner);
         vm.expectRevert("Address already set");
         nodeOperatorManagerInstance.setAuctionContractAddress(
             address(0)
         );
     }
}
