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

    event AdminAdded(address admin);
    event AdminRemoved(address admin);
    event AdminOperationsExecuted(address admin, bytes32 reportHash);

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

    function executeTasks(IEtherFiOracle.OracleReport calldata _report, bytes[] calldata _pubKey, bytes[] calldata _signature) external isAdmin(msg.sender) {
        bytes32 reportHash = etherFiOracle.generateReportHash(_report);
        require(etherFiOracle.isConsensusReached(reportHash), "EtherFiAdmin: not allowed to submit report");
        require(lastHandledReportRefSlot < _report.refSlotTo, "EtherFiAdmin: report already handled");
        require(lastHandledReportRefBlock < _report.refBlockTo, "EtherFiAdmin: report already handled");

        lastHandledReportRefSlot = _report.refSlotTo;
        lastHandledReportRefBlock = _report.refBlockTo;
        pendingWithdrawalAmount = _report.pendingWithdrawalAmount;
        numPendingValidatorsRequestedToExit = _report.numPendingValidatorsRequestedToExit;

        _handleAccruedRewards(_report);
        _handleValidators(_report, _pubKey, _signature);
        _handleWithdrawals(_report);
        _handleTargetFundsAllocations(_report);

        emit AdminOperationsExecuted(msg.sender, reportHash);
    }

    function _handleAccruedRewards(IEtherFiOracle.OracleReport calldata _report) internal {
        uint256 lpBalance = address(liquidityPool).balance;
        uint256 tvl = uint256(_report.accruedRewards + int256(lpBalance));
        membershipManager.rebase(lpBalance, tvl);
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
        // TODO enable it 
        // liquidityPool.setStakingTargetWeights(_report.eEthTargetAllocationWeight, _report.etherFanTargetAllocationWeight);
    }

    function addAdmin(address _admin) external onlyOwner {
        require(!admins[_admin], "EtherFiAdmin: admin already exists");
        admins[_admin] = true;

        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(admins[_admin], "EtherFiAdmin: admin does not exist");
        admins[_admin] = false;

        emit AdminRemoved(_admin);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    modifier isAdmin(address _admin) {
        require(admins[_admin], "EtherFiAdmin: not an admin");
        _;
    }
}