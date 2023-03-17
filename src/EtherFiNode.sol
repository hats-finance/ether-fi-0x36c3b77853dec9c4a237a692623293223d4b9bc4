// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IProtocolRevenueManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "lib/forge-std/src/console.sol";


contract EtherFiNode is IEtherFiNode {
    // TODO: immutable constants
    address etherfiNodesManager; // EtherFiNodesManager
    address protocolRevenueManagerAddress;

    uint256 public localRevenueIndex;
    uint256 public vestedAuctionRewards; 
    string public ipfsHashForEncryptedValidatorKey;
    uint32 public exitRequestTimestamp;
    uint32 public exitTimestamp;
    uint32 public stakingStartTimestamp;
    VALIDATOR_PHASE public phase;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    function initialize() public {
        require(etherfiNodesManager == address(0), "already initialised");
        etherfiNodesManager = msg.sender;
        stakingStartTimestamp = uint32(block.timestamp);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {
    }

    /// @notice Set the validator phase
    /// @param _phase the new phase
    function setPhase(
        VALIDATOR_PHASE _phase
    ) external onlyEtherFiNodeManagerContract {
        phase = _phase;
    }

    /// @notice Set the deposit data
    /// @param _ipfsHash the deposit data
    function setIpfsHashForEncryptedValidatorKey(
        string calldata _ipfsHash
    ) external onlyEtherFiNodeManagerContract {
        ipfsHashForEncryptedValidatorKey = _ipfsHash;
    }

    function setLocalRevenueIndex(
        uint256 _localRevenueIndex
    ) external onlyProtocolRevenueManagerContract {
        localRevenueIndex = _localRevenueIndex;
    }

    function setExitRequestTimestamp() external {
        require(exitRequestTimestamp == 0, "Exit request was already sent.");
        exitRequestTimestamp = uint32(block.timestamp);
    }

    function markExited() external onlyEtherFiNodeManagerContract {
        require(phase == VALIDATOR_PHASE.LIVE && exitTimestamp == 0, "Already marked as exited");
        phase = VALIDATOR_PHASE.EXITED;
        exitTimestamp = uint32(block.timestamp);
    }
    
    function receiveVestedRewardsForStakers() external payable onlyProtocolRevenueManagerContract {
        vestedAuctionRewards = msg.value;
    }

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external onlyEtherFiNodeManagerContract {
        (bool sent, ) = _treasury.call{value: _treasuryAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_operator).call{value: _operatorAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_tnftHolder).call{value: _tnftAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(_bnftHolder).call{value: _bnftAmount}("");
        require(sent, "Failed to send Ether");
    }

    function receiveProtocolRevenue(
        uint256 _globalRevenueIndex
    ) external payable onlyProtocolRevenueManagerContract {
        localRevenueIndex = _globalRevenueIndex;
    }

    function getStakingRewards(IEtherFiNodesManager.StakingRewardsSplit memory _splits, uint256 _scale) external view onlyEtherFiNodeManagerContract returns (uint256, uint256, uint256, uint256) {
        uint256 rewards = getAccruedStakingRewards();

        uint256 operator = (rewards * _splits.nodeOperator) / _scale;
        uint256 tnft = (rewards * _splits.tnft) / _scale;
        uint256 bnft = (rewards * _splits.bnft) / _scale;
        uint256 treasury = rewards - (bnft + tnft + operator);

        uint256 daysPassedSinceExitRequest = _getDaysPassedSince(exitRequestTimestamp, uint32(block.timestamp));
        if (daysPassedSinceExitRequest >= 14) {
            treasury += operator;
            operator = 0;
        }

        return (operator, tnft, bnft, treasury);
    }

    function getNonExitPenaltyAmount(uint256 _principal, uint256 _dailyPenalty) external view onlyEtherFiNodeManagerContract returns (uint256) {
        uint256 daysElapsed = _getDaysPassedSince(exitRequestTimestamp, uint32(block.timestamp));
        uint256 daysPerWeek = 7;
        uint256 weeksElapsed = daysElapsed / daysPerWeek;

        uint256 remaining = _principal;
        if (daysElapsed > 365) {
            remaining = 0;
        } else {
            for (uint64 i = 0; i < weeksElapsed; i++) {
                remaining = (remaining * (100 - _dailyPenalty) ** daysPerWeek) / (100 ** daysPerWeek);
            }

            daysElapsed -= weeksElapsed * daysPerWeek;
            for (uint64 i = 0; i < daysElapsed; i++) {
                remaining = (remaining * (100 - _dailyPenalty)) / 100;
            }
        }

        uint256 penaltyAmount = _principal - remaining;
        require(
            penaltyAmount <= _principal && penaltyAmount >= 0,
            "Incorrect penalty amount"
        );

        return penaltyAmount;
    }

    function getAccruedStakingRewards() public view returns (uint256) {
        return address(this).balance - vestedAuctionRewards;
    }

    function _getClaimableVestedRewards() internal returns (uint256) {
        uint256 vestingPeriodInDays = IProtocolRevenueManager(protocolRevenueManagerAddress).auctionFeeVestingPeriodForStakersInDays();
        uint256 daysPassed = _getDaysPassedSince(stakingStartTimestamp, uint32(block.timestamp));
        if (daysPassed >= vestingPeriodInDays) {
            uint256 _vestedAuctionRewards = vestedAuctionRewards;
            // vestedAuctionRewards = 0;
            return _vestedAuctionRewards;
        } else {
            return 0;
        }
    }

    function _getDaysPassedSince(uint32 _startTimestamp, uint32 _endTimestamp) internal view returns (uint256) {
        uint256 timeElapsed = _endTimestamp - _startTimestamp;
        return uint256(timeElapsed / (24 * 3600));
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyEtherFiNodeManagerContract() {
        require(msg.sender == etherfiNodesManager, "Only owner");
        _;
    }

    // TODO
    modifier onlyProtocolRevenueManagerContract() {
        // require(
        //     msg.sender == protocolRevenueContract,
        //     "Only protocol revenue manager contract function"
        // );
        _;
    }
}
