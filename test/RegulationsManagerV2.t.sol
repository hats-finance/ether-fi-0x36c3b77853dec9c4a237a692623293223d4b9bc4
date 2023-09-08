// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/RegulationsManagerV2.sol";

contract RegulationsManagerV2Test is Test {

    RegulationsManagerV2 regulationsManager;
    uint256 adminKey;
    address admin;
    uint256 aliceKey;
    address alice;

    function setUp() public {

        // setup keys
        adminKey = 0x1;
        aliceKey = 0x2;
        admin = vm.addr(adminKey);
        alice = vm.addr(aliceKey);

        // deploy
        vm.prank(admin);
        regulationsManager = new RegulationsManagerV2();
    }


    function test_verifyTermsSignature() public {

        // admin sets terms
        vm.prank(admin);
        regulationsManager.updateTermsOfService("I agree to Ether.fi ToS", hex"1234567890000000000000000000000000000000000000000000000000000000", "1");


        // alice signs terms and verifies
        vm.startPrank(alice);
        console2.log("alice", alice);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceKey, regulationsManager.generateTermsDigest());
        bytes memory signature = abi.encodePacked(r, s, v);
        regulationsManager.verifyTermsSignature(signature);
        vm.stopPrank();

        // admin should not be able to uses alice's signature
        vm.prank(admin);
        vm.expectRevert(RegulationsManagerV2.InvalidTermsAndConditionsSignature.selector);
        regulationsManager.verifyTermsSignature(signature);

        // alice should not be able to update the terms because she is not owner
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        regulationsManager.updateTermsOfService("Alice Rules, Brett Drools", "0xI_am_a_real_hash :)", "1");

    }

}
