// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract EtherFiOracleTest is TestSetup {
    function setUp() public {
        setUpTests();
    }

    function test_addCommitteeMember() public {
        etherFiOracleInstance.addCommitteeMember(alice);
        (bool enabled, uint32 lastReportRefSlot, uint32 numReports) = etherFiOracleInstance.committeeMemberStates(alice);
        assertEq(enabled, true);
        assertEq(lastReportRefSlot, 0);
        assertEq(numReports, 0);
    }
}
