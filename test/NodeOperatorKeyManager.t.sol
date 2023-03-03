// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NodeOperatorKeyManager.sol";
import "forge-std/console.sol";

contract NodeOperatorKeyManagerTest is Test {
    event OperatorRegistered(
        string ipfsHash,
        uint256 totalKeys,
        uint256 keysUsed
    );

    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;

    address alice = vm.addr(1);

    string aliceIPFSHash = "AliceIPFS";

    function setUp() public {
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
    }

    function test_RegisterNodeOperator() public {
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);
        (
            string memory aliceHash,
            uint256 totalKeys,
            uint256 keysUsed
        ) = nodeOperatorKeyManagerInstance.addressToOperatorData(alice);

        assertEq(aliceHash, aliceIPFSHash);
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);
    }

    function test_EventOperatorRegistered() public {
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(aliceIPFSHash, 10, 0);
        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 10);
    }
}
