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

    function test_verifyReport() public {
        // [timestamp = 1, period 1]
        // folks do nothing in this period

        skip(1000 * 12 seconds + 2 * 32 * 12 seconds);
        vm.roll(1000 + 2 * 32 + 1); // set block number

        // [timestamp = 12001 + 2 epochs, period 2]
        // alice isn't in the committee, should revert
        vm.expectRevert("You don't need to submit a report");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // add bob in the committee
        // add alice in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);

        // alice submits the period 2 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // alice submits another period 2 report
        vm.expectRevert("You don't need to submit a report");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // alice submits a different report
        vm.expectRevert("You don't need to submit a report");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2B);
        
        skip(1000 * 12 seconds - 2 * 32 * 12 seconds);
        vm.roll(2000 + 1); // set block number

        // [timestamp = 24001, period 3]

        // Not finalized
        vm.expectRevert("Report Epoch is not finalized yet");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod3);

        skip(2 * 32 * 12 seconds);
        vm.roll(2000 + 2 * 32 + 1);

        // alice submits reports with wrong {slotFrom, slotTo, blockFrom}
        vm.expectRevert("Report is for wrong slotFrom");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod4);

        // alice submits period 2 report
        vm.expectRevert("Report is for wrong slotTo");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // alice submits period 3 report, which is correct
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod3);
    }

    function test_submitReport() public {
        // add alice and bob in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);

        skip(1000 * 12 seconds + 2 * 32 * 12 seconds);
        vm.roll(1000 + 2 * 32 + 1); // set block number
        
        // Now it's period 2

        // alice submits the period 2 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);
        // check the member state
        (bool enabled, uint32 lastReportRefSlot, uint32 numReports) = etherFiOracleInstance.committeeMemberStates(alice);
        assertEq(enabled, true);
        assertEq(lastReportRefSlot, reportAtPeriod2A.refSlotTo);
        assertEq(numReports, 1);
        // check the consensus state
        bytes32 reportHash = etherFiOracleInstance.generateReportHash(reportAtPeriod2A);
        (uint32 support, bool consensusReached) = etherFiOracleInstance.consensusStates(reportHash);
        assertEq(support, 1);
        // bob submits the period 2 report
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);
        (support, consensusReached) = etherFiOracleInstance.consensusStates(reportHash);
        assertEq(support, 2);
    }

    function test_consensus() public {
        // add alice and bob in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);

        skip(1000 * 12 seconds + 2 * 32 * 12 seconds);
        vm.roll(1000 + 2 * 32 + 1); // set block number

        // Now it's period 2!

        // alice submits the period 2 report
        vm.prank(alice);
        bool consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod2A);
        assertEq(consensusReached, false);
        // bob submits the period 2 report, different
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod2B);
        assertEq(consensusReached, false);

        skip(1000 * 12 seconds);
        vm.roll(2000 + 2 * 32 + 1);

        // Now it's period 3

        // alice submits the period 3 report
        vm.prank(alice);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod3);
        assertEq(consensusReached, false);
        // bob submits the same period 3 report
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod3);
        assertEq(consensusReached, true);

        // 
        skip(1000 * 12 seconds);
        vm.roll(3000 + 2 * 32 + 1);

        // Now it's period 4
        
        vm.prank(alice);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod4);
        assertEq(consensusReached, false);
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod4);
        assertEq(consensusReached, true);
    }


}
