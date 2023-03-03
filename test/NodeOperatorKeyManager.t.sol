// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorKeyManager.sol";
import "forge-std/console.sol";

contract NodeOperatorKeyManagerTest is Test {
    event OperatorRegistered(
        uint128 totalKeys,
        uint128 keysUsed,
        string ipfsHash
    );

    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;

    address alice = vm.addr(1);

    bytes32 aliceIPFSHash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";

    function setUp() public {
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
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
}
