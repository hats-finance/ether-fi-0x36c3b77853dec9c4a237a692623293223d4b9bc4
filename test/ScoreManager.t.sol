// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "../src/ScoreManager.sol";

contract ScoreManagerTest is TestSetup {

    UUPSProxy public scoreManagerProxy;
    ScoreManager public scoreManagerInstance;
    ScoreManager public scoreManagerImplementation;
    
    function setUp() public {
        setUpTests();

        vm.startPrank(owner);
        scoreManagerImplementation = new ScoreManager();
        scoreManagerProxy = new UUPSProxy(address(scoreManagerImplementation), "");
        scoreManagerInstance = ScoreManager(address(scoreManagerProxy));
        scoreManagerInstance.initialize();
        vm.stopPrank();
    }

    function test_setScoreFailsIfAddressZero() public {
        vm.prank(owner);
        scoreManagerInstance.switchCallerStatus(alice);

        vm.prank(alice);
        vm.expectRevert("Cannot be address zero");
        scoreManagerInstance.setScore("category_1", address(0), "0x1234");
    }

    function test_setScoreFailsIfCallerNotAllowed() public {
        vm.prank(alice);
        vm.expectRevert("Caller not permissioned");
        scoreManagerInstance.setScore("category_1", address(0), "0x1234");
    }

    function test_setScoreWorksCorrectly() public {
        vm.prank(owner);
        scoreManagerInstance.switchCallerStatus(alice);

        vm.prank(alice);
        scoreManagerInstance.setScore("category_1", bob, "0x1234");

        assertEq(scoreManagerInstance.scores("category_1", bob), "0x1234");
    }

    function test_switchCallerStatusFailsIfAddressZero() public {
        vm.prank(owner);
        vm.expectRevert("Cannot be address zero");
        scoreManagerInstance.switchCallerStatus(address(0));
    }

    function test_switchCallerStatusFailsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        scoreManagerInstance.switchCallerStatus(alice);
    }

    function test_switchCallerWorksCorrectly() public {
        assertEq(scoreManagerInstance.allowedCallers(alice), false);
        
        vm.prank(owner);
        scoreManagerInstance.switchCallerStatus(alice);

        assertEq(scoreManagerInstance.allowedCallers(alice), true);
    }
}
