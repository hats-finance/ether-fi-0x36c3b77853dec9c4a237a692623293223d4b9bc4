// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract RegulationsManagerTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_ConfirmEligibilityWorks() public {
        vm.startPrank(owner);
        regulationsManagerInstance.pauseContract();
        vm.expectRevert("Pausable: paused");
        regulationsManagerInstance.confirmEligibility("hash_example");
        regulationsManagerInstance.unPauseContract();
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(0, alice), false);
        
        vm.prank(alice);
        regulationsManagerInstance.confirmEligibility("hash_example");

        assertEq(regulationsManagerInstance.isEligible(0, alice), true);
        assertEq(regulationsManagerInstance.declarationHash(0, alice), "hash_example");
    }

    function test_RemoveFromWhitelistWorks() public {
        vm.prank(alice);
        vm.expectRevert("Incorrect Caller");
        regulationsManagerInstance.removeFromWhitelist(bob);

        vm.prank(alice);
        vm.expectRevert("User not whitelisted");
        regulationsManagerInstance.removeFromWhitelist(alice);

        vm.startPrank(owner);
        regulationsManagerInstance.pauseContract();
        vm.expectRevert("Pausable: paused");
        regulationsManagerInstance.removeFromWhitelist(alice);
        regulationsManagerInstance.unPauseContract();
        vm.stopPrank();

        vm.prank(alice);
        regulationsManagerInstance.confirmEligibility("hash_example");

        assertEq(regulationsManagerInstance.isEligible(0, alice), true);
        assertEq(regulationsManagerInstance.declarationHash(0, alice), "hash_example");

        vm.prank(owner);
        regulationsManagerInstance.removeFromWhitelist(alice);

        assertEq(regulationsManagerInstance.isEligible(0, alice), false);
        assertEq(regulationsManagerInstance.declarationHash(0,alice), "hash_example");

        vm.prank(bob);
        regulationsManagerInstance.confirmEligibility("hash_example_2");

        assertEq(regulationsManagerInstance.isEligible(0, bob), true);
        assertEq(regulationsManagerInstance.declarationHash(0, bob), "hash_example_2");

        vm.prank(bob);
        regulationsManagerInstance.removeFromWhitelist(bob);

        assertEq(regulationsManagerInstance.isEligible(0, bob), false);
        assertEq(regulationsManagerInstance.declarationHash(0, bob), "hash_example_2");
    }

    function test_ResetWhitelistWorks() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        regulationsManagerInstance.resetWhitelist();

        assertEq(regulationsManagerInstance.declarationIteration(), 0);

        regulationsManagerInstance.confirmEligibility("hash_example");
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(0, alice), true);
        assertEq(regulationsManagerInstance.declarationHash(0, alice), "hash_example");

        vm.prank(owner);
        regulationsManagerInstance.resetWhitelist();

        assertEq(regulationsManagerInstance.declarationIteration(), 1);
        assertEq(regulationsManagerInstance.isEligible(regulationsManagerInstance.declarationIteration(), alice), false);
    }
}
