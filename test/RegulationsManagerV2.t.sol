// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/RegulationsManagerV2.sol";

contract RegulationsManagerV2Test is Test {

    RegulationsManagerV2 regulationsManager;

    function setUp() public {
        regulationsManager = new RegulationsManagerV2();
        console2.log(address(regulationsManager));
    }

    function test_hashStruct() public {
        //RegulationManagerV2.TermsOfService memory currentTerms = regulationsManager.currentTerms();
        (bytes32 message, bytes32 hashOfTerms) = regulationsManager.currentTerms();
        bytes32 structHash = regulationsManager.hashStruct(RegulationsManagerV2.TermsOfService(
            {
                message: message,
                hashOfTerms: hashOfTerms
            }
        ));
        console2.logBytes32(message);
        console2.logBytes32(structHash);
    }

    function test_verifyTermsSignature() public {
        //bytes memory signature = new bytes(65);
        address alice = vm.addr(2);
        console2.log("alice", alice);

        vm.startPrank(alice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(2, regulationsManager.generateTermsDigest());
        bytes memory signature = abi.encodePacked(r, s, v);

        regulationsManager.verifyTermsSignature(signature);
        vm.stopPrank();
    }

}
