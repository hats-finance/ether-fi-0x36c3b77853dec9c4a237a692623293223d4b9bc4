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
        // add alice in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        // bob isn't in the committee, should revert
        vm.expectRevert("You don't need to submit a report");
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        // add bob in the committee
        etherFiOracleInstance.addCommitteeMember(bob);
        // alice submits the period 1 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        // alice submits another period 1 report
        vm.expectRevert("You don't need to submit a report");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        
        skip(100 * 12 seconds);
        // [timestamp = 1201, period 2]
        // alice submits reports with wrong {slotFrom, slotTo, blockFrom}
        vm.expectRevert("Report is for wrong slotFrom");
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod3);

        // Test Report Epoch is not finalized yet?????
    }

    function test_submitReport() public {
        // add alice and bob in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);
        // alice submits the period 1 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        // check the member state
        (bool enabled, uint32 lastReportRefSlot, uint32 numReports) = etherFiOracleInstance.committeeMemberStates(alice);
        assertEq(enabled, true);
        assertEq(lastReportRefSlot, reportAtPeriod1.refSlotTo);
        assertEq(numReports, 1);
        // check the consensus state
        bytes32 chunk1 = keccak256(abi.encode(reportAtPeriod1.consensusVersion, reportAtPeriod1.refSlotFrom, reportAtPeriod1.refSlotTo, reportAtPeriod1.refBlockFrom, reportAtPeriod1.refBlockTo, reportAtPeriod1.accruedRewards));
        bytes32 chunk2 = keccak256(abi.encode(reportAtPeriod1.approvedValidators, reportAtPeriod1.exitedValidators, reportAtPeriod1.slashedValidators, reportAtPeriod1.withdrawalRequestsToInvalidate, reportAtPeriod1.lastFinalizedWithdrawalRequestId));
        bytes32 reportHash = keccak256(abi.encodePacked(chunk1, chunk2));
        (uint32 support) = etherFiOracleInstance.consensusStates(reportHash);
        assertEq(support, 1);
        // bob submits the period 1 report
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        (uint32 support) = etherFiOracleInstance.consensusStates(reportHash);
        assertEq(support, 2);
    }

    function test_consensus() public {
        // [timestamp = 1, period 1]
        // add alice and bob in the committee
        etherFiOracleInstance.addCommitteeMember(alice);
        etherFiOracleInstance.addCommitteeMember(bob);
        // alice submits the period 1 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        // TODO: assertEq(consensusReached, false)
        // bob submits the period 1 report
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportArPeriod1);
        // TODO: assertEq(consensusReached, true)

        skip(100 * 12 seconds);
        // [timestamp = 1201, period 2]
        // alice submits the period 2 report
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod2A);
        // TODO: assertEq(consensusReached, false)
        // bob submits a different period 2 report
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportArPeriod2B);
        // TODO: assertEq(consensusReached, false)

        skip(100 * 12 seconds);
        // [timestamp = 2401, period 3]
        vm.prank(alice);
        etherFiOracleInstance.submitReport(reportArPeriod3);
        // TODO: assertEq(consensusReached, false)
        vm.prank(bob);
        etherFiOracleInstance.submitReport(reportArPeriod3);
        // TODO: assertEq(consensusReached, true)
    }


}
