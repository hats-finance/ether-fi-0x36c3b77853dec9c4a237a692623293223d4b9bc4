// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IEtherFiOracle.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IMembershipManager.sol";
import "./interfaces/IWithdrawRequestNFT.sol";


contract EtherFiAdmin is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    IEtherFiOracle public etherFiOracle;
    IStakingManager public stakingManager;
    IAuctionManager public auctionManager;
    IEtherFiNodesManager public etherFiNodesManager;
    ILiquidityPool public liquidityPool;
    IMembershipManager public membershipManager;
    IWithdrawRequestNFT public withdrawRequestNft;

    mapping(address => bool) public admins;

    uint32 public lastHandledReportRefSlot;
    uint32 public lastHandledReportRefBlock;
    uint32 public pendingWithdrawalAmount;
    uint32 public numPendingValidatorsRequestedToExit;
    uint32 public numValidatorsToSpinUp;

    event AdminUpdated(address _address, bool _isAdmin);
    event AdminOperationsExecuted(address _address, bytes32 _reportHash);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _etherFiOracle,
        address _stakingManager,
        address _auctionManager,
        address _etherFiNodesManager,
        address _liquidityPool,
        address _membershipManager,
        address _withdrawRequestNft
    ) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        etherFiOracle = IEtherFiOracle(_etherFiOracle);
        stakingManager = IStakingManager(_stakingManager);
        auctionManager = IAuctionManager(_auctionManager);
        etherFiNodesManager = IEtherFiNodesManager(_etherFiNodesManager);
        liquidityPool = ILiquidityPool(_liquidityPool);
        membershipManager = IMembershipManager(_membershipManager);
        withdrawRequestNft = IWithdrawRequestNFT(_withdrawRequestNft);
    }

    function executeTasks(IEtherFiOracle.OracleReport calldata _report, bytes[] calldata _pubKey, bytes[] calldata _signature) external isAdmin() {
        bytes32 reportHash = etherFiOracle.generateReportHash(_report);
        require(etherFiOracle.isConsensusReached(reportHash), "EtherFiAdmin: report didn't reach consensus");
        require(slotForNextReportToProcess() == _report.refSlotFrom, "EtherFiAdmin: report has wrong `refSlotFrom`");
        require(blockForNextReportToProcess() == _report.refBlockFrom, "EtherFiAdmin: report has wrong `refBlockFrom`");

        lastHandledReportRefSlot = _report.refSlotTo;
        lastHandledReportRefBlock = _report.refBlockTo;
        pendingWithdrawalAmount = _report.pendingWithdrawalAmount;
        numPendingValidatorsRequestedToExit = _report.numPendingValidatorsRequestedToExit;
        numValidatorsToSpinUp = _report.numValidatorsToSpinUp;

        _handleAccruedRewards(_report);
        _handleValidators(_report, _pubKey, _signature);
        _handleWithdrawals(_report);
        _handleTargetFundsAllocations(_report);

        emit AdminOperationsExecuted(msg.sender, reportHash);
    }

    function _handleAccruedRewards(IEtherFiOracle.OracleReport calldata _report) internal {
        membershipManager.rebase(_report.accruedRewards);
    }

    function _handleValidators(IEtherFiOracle.OracleReport calldata _report, bytes[] calldata _pubKey, bytes[] calldata _signature) internal {
        // validatorsToApprove
        stakingManager.batchApproveRegistration(_report.validatorsToApprove, _pubKey, _signature);

        // liquidityPoolValidatorsToExit
        liquidityPool.sendExitRequests(_report.liquidityPoolValidatorsToExit);

        // exitedValidators
        uint32[] memory _exitTimestamps = new uint32[](_report.exitedValidators.length);
        for (uint256 i = 0; i < _report.exitedValidators.length; i++) {
            _exitTimestamps[i] = uint32(block.timestamp);
        }
        etherFiNodesManager.processNodeExit(_report.exitedValidators, _exitTimestamps);

        // slashedValidators
        etherFiNodesManager.markBeingSlashed(_report.slashedValidators);
    }

    function _handleWithdrawals(IEtherFiOracle.OracleReport calldata _report) internal {
        for (uint256 i = 0; i < _report.withdrawalRequestsToInvalidate.length; i++) {
            withdrawRequestNft.invalidateRequest(_report.withdrawalRequestsToInvalidate[i]);
        }
        withdrawRequestNft.finalizeRequests(_report.lastFinalizedWithdrawalRequestId);
    }

    function _handleTargetFundsAllocations(IEtherFiOracle.OracleReport calldata _report) internal {
        if (_report.eEthTargetAllocationWeight == 0 || _report.etherFanTargetAllocationWeight == 0) {
            return;
        }
        liquidityPool.setStakingTargetWeights(_report.eEthTargetAllocationWeight, _report.etherFanTargetAllocationWeight);
    }

    function slotForNextReportToProcess() public view returns (uint32) {
        return (lastHandledReportRefSlot == 0) ? 0 : lastHandledReportRefSlot + 1;
    }

    function blockForNextReportToProcess() public view returns (uint32) {
        return (lastHandledReportRefBlock == 0) ? 0 : lastHandledReportRefBlock + 1;
    }

    function updateNumberOfValidatorsToSpinUp(uint32 _numberOfValidators) external isAdmin {
        numValidatorsToSpinUp = _numberOfValidators;
    }

    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;

        emit AdminUpdated(_address, _isAdmin);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    modifier isAdmin() {
        require(admins[msg.sender], "EtherFiAdmin: not an admin");
        _;
    }
}