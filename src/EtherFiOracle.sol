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
        uint32[] validatorsToApprove;
        uint32[] validatorsToExit;
        uint32[] exitedValidators;
        uint32[] slashedValidators;
        uint32[] withdrawalRequestsToInvalidate;
        uint32 lastFinalizedWithdrawalRequestId;
    }

    struct CommitteeMemberState {
        bool registered;
        bool enabled; // is the member allowed to submit the report
        uint32 lastReportRefSlot; // the ref slot of the last report from the member
        uint32 numReports; // number of reports by the member
    }

    struct ConsensusState {
        uint32 support; // how many supports?
        bool consensusReached; // if the consensus is reached for this report
    }

    mapping(address => CommitteeMemberState) public committeeMemberStates; // committee member wallet address to its State
    mapping(bytes32 => ConsensusState) public consensusStates; // report's hash -> Consensus State

    uint32 public consensusVersion; // the version of the consensus
    uint32 public quorumSize; // the required supports to reach the consensus
    uint32 public reportPeriodSlot; // the period of the oracle report in # of slots

    uint32 public numCommitteeMembers; // the total number of committee members
    uint32 public numActiveCommitteeMembers; // the number of active (enabled) committee members

    uint32 public lastPublishedReportRefSlot; // the ref slot of the last published report
    uint32 public lastPublishedReportRefBlock; // the ref block of the last published report

    uint32 public lastHandledReportRefSlot;

    /// Chain specification
    uint32 internal SLOTS_PER_EPOCH;
    uint32 internal SECONDS_PER_SLOT;
    uint32 internal BEACON_GENESIS_TIME;


    event CommitteeMemberAdded(address member);
    event CommitteeMemberRemoved(address member);
    event CommitteeMemberUpdated(address member, bool enabled);
    event QuorumUpdated(uint32 newQuorumSize);
    event ConsensusVersionUpdated(uint32 newConsensusVersion);
    event OracleReportPeriodUpdated(uint32 newOracleReportPeriod);

    event ReportPublishsed(uint32 consensusVersion, uint32 refSlotFrom, uint32 refSlotTo, uint32 refBlockFrom, uint32 refBlockTo, bytes32 hash);
    event ReportSubmitted(uint32 consensusVersion, uint32 refSlotFrom, uint32 refSlotTo, uint32 refBlockFrom, uint32 refBlockTo, bytes32 hash, address committeeMembe);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint32 _quorumSize, uint32 _reportPeriodSlot, uint32 _slotsPerEpoch, uint32 _secondsPerSlot, uint32 _genesisTime)
        external
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();

        consensusVersion = 1;
        reportPeriodSlot = _reportPeriodSlot;
        quorumSize = _quorumSize;
        SLOTS_PER_EPOCH = _slotsPerEpoch;
        SECONDS_PER_SLOT = _secondsPerSlot;
        BEACON_GENESIS_TIME = _genesisTime;
    }

    function submitReport(OracleReport calldata _report) external returns (bool) {
        require(shouldSubmitReport(msg.sender), "You don't need to submit a report");
        verifyReport(_report);

        bytes32 reportHash = generateReportHash(_report);

        // update the member state
        CommitteeMemberState storage memberState = committeeMemberStates[msg.sender];
        memberState.lastReportRefSlot = _report.refSlotTo;
        memberState.numReports++;

        // update the consensus state
        ConsensusState storage consenState = consensusStates[reportHash];
        consenState.support++;

        // if the consensus reaches
        bool consensusReached = (consenState.support == quorumSize);
        if (consensusReached) {
            consenState.consensusReached = true;
            _publishReport(_report, reportHash);
        }

        emit ReportSubmitted(
            _report.consensusVersion,
            _report.refSlotFrom,
            _report.refSlotTo,
            _report.refBlockFrom,
            _report.refBlockTo,
            reportHash,
            msg.sender
            );

        return consensusReached;
    }

    // For generating the next report, the starting & ending points need to be specified.
    // The report should include data for the specified slot and block ranges (inclusive)
    function blockStampForNextReport() public view returns (uint32 slotFrom, uint32 slotTo, uint32 blockFrom) {
        slotFrom = lastPublishedReportRefSlot == 0 ? 0 : lastPublishedReportRefSlot + 1;
        slotTo = _slotForNextReport();
        blockFrom = lastPublishedReportRefBlock == 0 ? 0 : lastPublishedReportRefBlock + 1;
        // `blockTo` can't be decided since a slot may not have any block (`missed slot`)
    }

    function shouldSubmitReport(address _member) public view returns (bool) {
        require(committeeMemberStates[_member].registered, "You are not registered as the Oracle committee member");
        require(committeeMemberStates[_member].enabled, "You are disabled");
        uint32 slot = _slotForNextReport();
        require(_isFinalized(slot), "Report Epoch is not finalized yet");
        return slot > committeeMemberStates[_member].lastReportRefSlot;
    }

    function verifyReport(OracleReport calldata _report) public view {
        require(_report.consensusVersion == consensusVersion, "Report is for wrong consensusVersion");

        (uint32 slotFrom, uint32 slotTo, uint32 blockFrom) = blockStampForNextReport();
        require(_report.refSlotFrom == slotFrom, "Report is for wrong slotFrom");
        require(_report.refSlotTo == slotTo, "Report is for wrong slotTo");
        require(_report.refBlockFrom == blockFrom, "Report is for wrong blockFrom");
        require(_report.refBlockTo < block.number, "Report is for wrong blockTo");

        // If two epochs in a row are justified, the current_epoch - 2 is considered finalized
        uint32 currSlot = _computeSlotAtTimestamp(block.timestamp);
        uint32 currEpoch = (currSlot / SLOTS_PER_EPOCH);
        uint32 reportEpoch = (_report.refSlotTo / SLOTS_PER_EPOCH);
        require(reportEpoch < currEpoch - 2, "Report Epoch is not finalized yet");
    }

    function isConsensusReached(bytes32 _hash) public view returns (bool) {
        return consensusStates[_hash].consensusReached;
    }

    function _isFinalized(uint32 _slot) internal view returns (bool) {
        uint32 currSlot = _computeSlotAtTimestamp(block.timestamp);
        uint32 currEpoch = (currSlot / SLOTS_PER_EPOCH);
        uint32 slotEpoch = (_slot / SLOTS_PER_EPOCH);
        return slotEpoch < currEpoch - 2;
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

    // Given the last published report AND the current slot number,
    // Return the next report's `slotTo` that we are waiting for
    // https://docs.google.com/spreadsheets/d/1U0Wj4S9EcfDLlIab_sEYjWAYyxMflOJaTrpnHcy3jdg/edit?usp=sharing
    function _slotForNextReport() internal view returns (uint32) {
        uint32 currSlot = _computeSlotAtTimestamp(block.timestamp);
        uint32 pastSlot = lastPublishedReportRefSlot == 0 ? 0 : lastPublishedReportRefSlot + 1;
        uint32 tmp = pastSlot + ((currSlot - pastSlot) / reportPeriodSlot) * reportPeriodSlot;
        uint32 __slotForNextReport = (tmp > pastSlot + reportPeriodSlot) ? tmp : pastSlot + reportPeriodSlot;
        return __slotForNextReport - 1;
    }

    function _computeSlotAtTimestamp(uint256 timestamp) public view returns (uint32) {
        return uint32((timestamp - BEACON_GENESIS_TIME) / SECONDS_PER_SLOT);
    }

    function generateReportHash(OracleReport calldata _report) public pure returns (bytes32) {
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
                _report.validatorsToApprove,
                _report.validatorsToExit,
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
        require(committeeMemberStates[_address].registered == false, "Already registered");
        numCommitteeMembers++;
        numActiveCommitteeMembers++;
        committeeMemberStates[_address] = CommitteeMemberState(true, true, 0, 0);

        emit CommitteeMemberAdded(_address);
    }

    // only admin
    function removeCommitteeMember(address _address) public {
        require(committeeMemberStates[_address].registered == true, "Not registered");
        numCommitteeMembers--;
        delete committeeMemberStates[_address];

        emit CommitteeMemberRemoved(_address);
    }

    // only admin
    function manageCommitteeMember(address _address, bool _enabled) public {
        require(committeeMemberStates[_address].registered == true, "Not registered");
        require(committeeMemberStates[_address].enabled != _enabled, "Already in the target state");
        committeeMemberStates[_address].enabled = _enabled;
        if (_enabled) {
            numActiveCommitteeMembers++;
        } else {
            numActiveCommitteeMembers--;
        }

        emit CommitteeMemberUpdated(_address, _enabled);
    }

    function setQuorumSize(uint32 _quorumSize) public onlyOwner {
        quorumSize = _quorumSize;

        emit QuorumUpdated(_quorumSize);
    }

    function setOracleReportPeriod(uint32 _reportPeriodSlot) public onlyOwner {
        require(reportPeriodSlot % SLOTS_PER_EPOCH == 0, "Report period must be a multiple of the epoch");
        reportPeriodSlot = _reportPeriodSlot;

        emit OracleReportPeriodUpdated(reportPeriodSlot);
    }

    function setConsensusVersion(uint32 _consensusVersion) public onlyOwner {
        require(_consensusVersion > consensusVersion, "New consensus version must be greater than the current one");
        consensusVersion = _consensusVersion;

        emit ConsensusVersionUpdated(_consensusVersion);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
