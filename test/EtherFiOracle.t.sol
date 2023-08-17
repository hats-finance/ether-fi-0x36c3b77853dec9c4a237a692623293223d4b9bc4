// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract EtherFiOracleTest is TestSetup {
    function setUp() public {
        setUpTests();

        // Timestamp = 1, BlockNumber = 0
        vm.roll(0);

        console.log(etherFiOracleInstance.owner());

        vm.startPrank(owner);
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);
        vm.stopPrank();
    }

    function test_addCommitteeMember() public {
        _moveClock(1024 + 2 * slotsPerEpoch);

        // chad is not a commitee member
        vm.prank(chad);
        vm.expectRevert("You don't need to submit a report");
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // chad is added to the committee
        vm.prank(owner);
        etherFiOracleInstance.addCommitteeMember(chad);
        (bool registered, bool enabled, uint32 lastReportRefSlot, uint32 numReports) = etherFiOracleInstance.committeeMemberStates(chad);
        assertEq(registered, true);
        assertEq(enabled, true);
        assertEq(lastReportRefSlot, 0);
        assertEq(numReports, 0);

        // chad submits a report
        vm.prank(chad);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        _moveClock(1024);

        // Owner disables chad's report submission
        vm.prank(owner);
        etherFiOracleInstance.manageCommitteeMember(chad, false);
        (registered, enabled, lastReportRefSlot, numReports) = etherFiOracleInstance.committeeMemberStates(chad);
        assertEq(registered, true);
        assertEq(enabled, false);
        assertEq(lastReportRefSlot, 1024);
        assertEq(numReports, 1);

        // chad fails to submit a report
        vm.prank(chad);
        vm.expectRevert("You don't need to submit a report");
        etherFiOracleInstance.submitReport(reportAtPeriod3);
    }

    function test_epoch_not_finzlied() public {
        vm.startPrank(alice);

        // The report `reportAtPeriod2A` is for slot 1024 = epoch 32
        // Which can be submitted after the slot 1088 = epoch 34

        // At timpestamp = 12301, blocknumber = 1025, epoch = 32
        _moveClock(1024 + 1);
        vm.expectRevert("Report Epoch is not finalized yet");
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // At timpestamp = 12685, blocknumber = 1057, epoch = 33
        _moveClock(1 * slotsPerEpoch);
        vm.expectRevert("Report Epoch is not finalized yet");
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // At timpestamp = 13045, blocknumber = 1087, epoch = 33
        _moveClock(30);
        vm.expectRevert("Report Epoch is not finalized yet");
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // At timpestamp = 13057, blocknumber = 1088, epoch = 34
        _moveClock(1);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        vm.stopPrank();
    }

    function test_wrong_consensus_version() public {
        _moveClock(1024 + 2 * slotsPerEpoch);

        // Consensus Version = 0
        vm.prank(owner);
        etherFiOracleInstance.setConsensusVersion(0);

        // alice submits the period 2 report with wrong consensus version
        vm.prank(alice);
        vm.expectRevert("Report is for wrong consensusVersion");
        etherFiOracleInstance.submitReport(reportAtPeriod2B);

       // Consensus Version = 1
        vm.prank(owner);
        etherFiOracleInstance.setConsensusVersion(1);

        // alice submits the period 2 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);
    }

    function test_verifyReport() public {
        _moveClock(1024 + 2 * slotsPerEpoch);
        // [timestamp = 13057, period 2]
        // (13057 - 1) / 12 / 32 = 34 epoch

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
        
        _moveClock(1024 );
        // [timestamp = 25345, period 3]
        // 66 epoch

        // alice submits reports with wrong {slotFrom, slotTo, blockFrom}
        vm.expectRevert("Report is for wrong slotFrom");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod4);

        // alice submits period 2 report
        vm.expectRevert("Report is for wrong slotTo");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);

        // alice submits period 3A report
        vm.expectRevert("Report is for wrong blockTo");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod3A);

        // alice submits period 3B report
        vm.expectRevert("Report is for wrong blockFrom");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod3B);

        // alice submits period 3 report, which is correct
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod3);
    }

    function test_submitReport() public {
        _moveClock(1024 + 2 * slotsPerEpoch);
        
        // Now it's period 2

        // alice submits the period 2 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportAtPeriod2A);
        
        // check the member state
        (bool registered, bool enabled, uint32 lastReportRefSlot, uint32 numReports) = etherFiOracleInstance.committeeMemberStates(alice);
        assertEq(registered, true);
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

        assertEq(etherFiOracleInstance.lastPublishedReportRefSlot(), reportAtPeriod2A.refSlotTo);
        assertEq(etherFiOracleInstance.lastPublishedReportRefBlock(), reportAtPeriod2A.refBlockTo);
    }

    function test_consensus() public {
        // Now it's period 2!
        _moveClock(1024 + 2 * slotsPerEpoch);

        // alice submits the period 2 report
        vm.prank(alice);
        bool consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod2A);
        assertEq(consensusReached, false);
        // bob submits the period 2 report, different
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod2B);
        assertEq(consensusReached, false);

        // Now it's period 3
        _moveClock(1024);

        // alice submits the period 3 report
        vm.prank(alice);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod3);
        assertEq(consensusReached, false);
        // bob submits the same period 3 report
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod3);
        assertEq(consensusReached, true);

        // Now it's period 4
        _moveClock(1024);
        
        vm.prank(alice);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod4);
        assertEq(consensusReached, false);
        vm.prank(bob);
        consensusReached = etherFiOracleInstance.submitReport(reportAtPeriod4);
        assertEq(consensusReached, true);
    }


}
