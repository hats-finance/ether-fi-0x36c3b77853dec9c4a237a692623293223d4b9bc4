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
        vm.startPrank(alice);
        assertEq(nodeOperatorManagerInstance.registered(alice), false);
        nodeOperatorManagerInstance.registerNodeOperator(
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
            aliceIPFS_Hash,
            uint64(10)
        );
    }

    function test_EventOperatorRegistered() public {
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(10, 0, aliceIPFS_Hash);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceIPFS_Hash,
            10
        );
    }

    function test_FetchNextKeyIndex() public {
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
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

    function test_CanOnlySetAddressesOnce() public {
         vm.startPrank(owner);
         vm.expectRevert("Address already set");
         nodeOperatorManagerInstance.setAuctionContractAddress(
             address(0)
         );
     }
}
