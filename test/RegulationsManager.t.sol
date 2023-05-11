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
        regulationsManagerInstance.confirmEligibility("USA, CANADA");
        regulationsManagerInstance.unPauseContract();
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(0, alice), false);
        
        vm.startPrank(alice);
        vm.expectRevert("Incorrect hash");
        regulationsManagerInstance.confirmEligibility("Hash_Example");

        regulationsManagerInstance.confirmEligibility("USA, CANADA");

        assertEq(regulationsManagerInstance.isEligible(1, alice), true);
    }

    function test_RemoveFromWhitelistWorks() public {
        vm.prank(alice);
        vm.expectRevert("Incorrect Caller");
        regulationsManagerInstance.removeFromWhitelist(bob);

        vm.prank(alice);
        vm.expectRevert("User is not whitelisted");
        regulationsManagerInstance.removeFromWhitelist(alice);

        vm.startPrank(owner);
        regulationsManagerInstance.pauseContract();
        vm.expectRevert("Pausable: paused");
        regulationsManagerInstance.removeFromWhitelist(alice);
        regulationsManagerInstance.unPauseContract();
        vm.stopPrank();

        vm.prank(alice);
        regulationsManagerInstance.confirmEligibility("USA, CANADA");


        assertEq(regulationsManagerInstance.isEligible(1, alice), true);

        vm.prank(owner);
        regulationsManagerInstance.removeFromWhitelist(alice);

        assertEq(regulationsManagerInstance.isEligible(1, alice), false);

        vm.prank(bob);
        regulationsManagerInstance.confirmEligibility("USA, CANADA");

        assertEq(regulationsManagerInstance.isEligible(1, bob), true);

        vm.prank(bob);
        regulationsManagerInstance.removeFromWhitelist(bob);

        assertEq(regulationsManagerInstance.isEligible(1, bob), false);
    }

    function test_initializeNewWhitelistWorks() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        regulationsManagerInstance.initializeNewWhitelist("USA, CANADA");

        assertEq(regulationsManagerInstance.whitelistVersion(), 1);

        regulationsManagerInstance.confirmEligibility("USA, CANADA");
        vm.stopPrank();

        assertEq(regulationsManagerInstance.isEligible(1, alice), true);

        vm.prank(owner);
        regulationsManagerInstance.initializeNewWhitelist("USA, CANADA, FRANCE");

        assertEq(regulationsManagerInstance.whitelistVersion(), 2);
        assertEq(regulationsManagerInstance.isEligible(regulationsManagerInstance.whitelistVersion(), alice), false);
    }
}
