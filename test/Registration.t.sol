// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Registration.sol";
import "forge-std/console.sol";

contract RegistrationTest is Test {
    event OperatorRegistered(
        string ipfsHash,
        uint256 totalKeys,
        uint256 keysUsed
    );

    Registration registrationInstance;

    address alice = vm.addr(1);

    string aliceIPFSHash = "AliceIPFS";

    function setUp() public {
        registrationInstance = new Registration();
    }

    function test_RegisterNodeOperator() public {
        vm.prank(alice);
        registrationInstance.registerNodeOperator(aliceIPFSHash, 10);
        (
            string memory aliceHash,
            uint256 totalKeys,
            uint256 keysUsed
        ) = registrationInstance.addressToOperatorData(alice);

        assertEq(aliceHash, aliceIPFSHash);
        assertEq(totalKeys, 10);
        assertEq(keysUsed, 0);
    }

    function test_EventOperatorRegistered() public {
        vm.expectEmit(false, false, false, true);
        emit OperatorRegistered(aliceIPFSHash, 10, 0);
        vm.prank(alice);
        registrationInstance.registerNodeOperator(aliceIPFSHash, 10);
    }
}
