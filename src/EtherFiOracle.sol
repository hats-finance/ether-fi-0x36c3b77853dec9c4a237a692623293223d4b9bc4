// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract EtherFiOracle is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct OracleReport {
        uint16 consensusVersion;
        uint32 refSlotFrom;
        uint32 refSlotTo;
        uint32 refBlockFrom;
        uint32 refBlockTo;
        int256 accruedRewards;
        uint32[] approvedValidators;
        uint32[] exitedValidators;
        uint32[] slashedValidators;
        uint32[] withdrawalRequestsToInvalidate;
        uint32 lastFinalizedWithdrawalRequestId;
    }

    struct CommitteeMemberState {
        bool enabled; // is the member allowed to submit the report
        uint32 lastReportRefSlot; // the ref slot of the last report from the member
        uint32 numReports; // number of reports by the member
    }

    struct ConsensusState {
        uint32 support; // how many supports?
    }

    mapping(address => CommitteeMemberState) public committeeMemberStates; // committee member wallet address to its State
    mapping(bytes32 => ConsensusState) public consensusStates; // report's hash -> Consensus State

    uint32 consensusVersion; // the version of the consensus
    uint32 quorumSize; // the required supports to reach the consensus
    uint32 reportPeriodSlot; // the period of the oracle report in # of slots

    uint32 lastPublishedReportRefSlot; // the ref slot of the last published report
    uint32 lastPublishedReportRefBlock; // the ref block of the last published report

    uint32 lastHandledReportRefSlot;

    /// Chain specification
    uint64 internal SLOTS_PER_EPOCH;
    uint64 internal SECONDS_PER_SLOT;
    uint64 internal GENESIS_TIME;

    // emit when the report is published, the admin node will subscribe to this event
    event ReportPublishsed(
        uint16 consensusVersion,
        uint32 refSlotFrom,
        uint32 refSlotTo,
        uint32 refBlockFrom,
        uint32 refBlockTo,
        bytes32 hash
    );
    event QuorumUpdated(uint32 newQuorumSize);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint32 _quorumSize, uint64 _slotsPerEpoch, uint64 _secondsPerSlot, uint64 _genesisTime)
        external
        initializer
    {
        quorumSize = _quorumSize;
        SLOTS_PER_EPOCH = _slotsPerEpoch;
        SECONDS_PER_SLOT = _secondsPerSlot;
        GENESIS_TIME = _genesisTime;
    }

    function submitReport(OracleReport calldata _report) external {
        verifyReport(_report);

        bytes32 hash = _generateReportHash(_report);

        // update the member state
        CommitteeMemberState storage memberState = committeeMemberStates[msg.sender];
        memberState.lastReportRefSlot = _report.refSlotTo;
        memberState.numReports++;

        // update the consensus state
        ConsensusState storage consenState = consensusStates[hash];
        consenState.support++;

        // if the consensus reaches
        bool consensusReached = (consenState.support == quorumSize);
        if (consensusReached) {
            _publishReport(_report, hash);
        }
    }

    // Given the last published report AND the current slot number,
    // Return the next report's slot that we are waiting for
    // https://docs.google.com/spreadsheets/d/1U0Wj4S9EcfDLlIab_sEYjWAYyxMflOJaTrpnHcy3jdg/edit?usp=sharing
    function slotForNextReport() public view returns (uint32) {
        uint32 currSlot = _computeSlotAtTimestamp(block.timestamp);
        uint32 pastSlot = lastPublishedReportRefSlot;
        uint32 tmp = pastSlot + ((currSlot - pastSlot) / reportPeriodSlot) * reportPeriodSlot;
        uint32 _slotForNextReport = (tmp > pastSlot + reportPeriodSlot) ? tmp : pastSlot + reportPeriodSlot;
        return _slotForNextReport;
    }

    // For generating the next report, the starting & ending points need to be specified.
    // The report should include data for the specified slot and block ranges (inclusive)
    function blockStampForNextReport() public view returns (uint32 slotFrom, uint32 slotTo, uint32 blockFrom) {
        slotFrom = lastPublishedReportRefSlot + 1;
        slotTo = slotForNextReport();
        blockFrom = lastPublishedReportRefBlock + 1;
        // `blockTo` can't be decided since a slot may not have any block (`missed slot`)
    }

    function shouldSubmitReport(address _member) public view returns (bool) {
        if (!committeeMemberStates[msg.sender].enabled) return false;
        return slotForNextReport() > committeeMemberStates[_member].lastReportRefSlot;
    }

    function verifyReport(OracleReport calldata _report) public view {
        require(shouldSubmitReport(msg.sender), "You don't need to submit a report");

        (uint32 slotFrom, uint32 slotTo, uint32 blockFrom) = blockStampForNextReport();
        require(_report.refSlotFrom != slotFrom, "Report is for wrong slotFrom");
        require(_report.refSlotTo != slotTo, "Report is for wrong slotTo");
        require(_report.refBlockFrom != blockFrom, "Report is for wrong blockFrom");
        require(_report.refBlockTo >= block.number, "Report is for wrong blcokTo");

        // If two epochs in a row are justified, the current_epoch - 2 is considered finalized
        uint32 currSlot = _computeSlotAtTimestamp(block.timestamp);
        uint32 currEpoch = (currSlot / 32);
        uint32 reportEpoch = (_report.refSlotTo / 32);
        require(reportEpoch <= currEpoch - 2, "Report Epoch is not finalized yet");
    }

    function _publishReport(OracleReport calldata _report, bytes32 _hash) internal {
        lastPublishedReportRefSlot = _report.refSlotTo;
        lastPublishedReportRefBlock = _report.refBlockTo;

        // emit report published event
        emit ReportPublishsed(
            _report.consensusVersion,
            _report.refSlotFrom,
            _report.refSlotTo,
            _report.refBlockFrom,
            _report.refBlockTo,
            _hash
            );
    }

    function _computeSlotAtTimestamp(uint256 timestamp) public view returns (uint32) {
        return uint32((timestamp - GENESIS_TIME) / SECONDS_PER_SLOT);
    }

    function _generateReportHash(OracleReport calldata _report) internal pure returns (bytes32) {
        bytes32 chunk1 = keccak256(
            abi.encode(
                _report.consensusVersion,
                _report.refSlotFrom,
                _report.refSlotTo,
                _report.refBlockFrom,
                _report.refBlockTo,
                _report.accruedRewards
            )
        );

        bytes32 chunk2 = keccak256(
            abi.encode(
                _report.approvedValidators,
                _report.exitedValidators,
                _report.slashedValidators,
                _report.withdrawalRequestsToInvalidate,
                _report.lastFinalizedWithdrawalRequestId
            )
        );

        return keccak256(abi.encodePacked(chunk1, chunk2));
    }

    // only admin
    function addCommitteeMember(address _address) public {
        committeeMemberStates[_address] = CommitteeMemberState(true, 0, 0);
    }

    // only admin
    function manageCommitteeMember(address _address, bool _enabled) public {
        committeeMemberStates[_address].enabled = _enabled;
    }

    // only admin
    function setQuorumSize(uint32 _quorumSize) public {
        quorumSize = _quorumSize;
        emit QuorumUpdated(_quorumSize);
    }

    // only admin
    function setOracleReportPeriod(uint32 _reportPeriodSlot) public {
        reportPeriodSlot = _reportPeriodSlot;
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
