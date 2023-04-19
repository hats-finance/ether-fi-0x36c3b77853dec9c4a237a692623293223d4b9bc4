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
        regulationsManagerInstance.confirmEligibility();
        regulationsManagerInstance.unPauseContract();
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(0, alice), false);
        
        vm.prank(alice);
        regulationsManagerInstance.confirmEligibility();

        assertEq(regulationsManagerInstance.isEligible(0, alice), true);
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
        regulationsManagerInstance.confirmEligibility();


        assertEq(regulationsManagerInstance.isEligible(0, alice), true);

        vm.prank(owner);
        regulationsManagerInstance.removeFromWhitelist(alice);

        assertEq(regulationsManagerInstance.isEligible(0, alice), false);

        vm.prank(bob);
        regulationsManagerInstance.confirmEligibility();

        assertEq(regulationsManagerInstance.isEligible(0, bob), true);

        vm.prank(bob);
        regulationsManagerInstance.removeFromWhitelist(bob);

        assertEq(regulationsManagerInstance.isEligible(0, bob), false);
    }

    function test_ResetWhitelistWorks() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        regulationsManagerInstance.resetWhitelist();

        assertEq(regulationsManagerInstance.whitelistVersion(), 0);

        regulationsManagerInstance.confirmEligibility();
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(0, alice), true);

        vm.prank(owner);
        regulationsManagerInstance.resetWhitelist();

        assertEq(regulationsManagerInstance.whitelistVersion(), 1);
        assertEq(regulationsManagerInstance.isEligible(regulationsManagerInstance.whitelistVersion(), alice), false);
    }
}
