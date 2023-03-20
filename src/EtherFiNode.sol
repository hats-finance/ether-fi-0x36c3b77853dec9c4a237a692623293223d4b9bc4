// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/math/Math.sol";

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
    // TODO: Remove these two address variables
    address etherfiNodesManager;
    address protocolRevenueManager;

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

    function initialize(address _protocolRevenueManager) public {
        require(etherfiNodesManager == address(0), "already initialised");
        etherfiNodesManager = msg.sender;
        protocolRevenueManager = _protocolRevenueManager;
        stakingStartTimestamp = uint32(block.timestamp);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {}

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
    ) external onlyEtherFiNodeManagerContract {
        localRevenueIndex = _localRevenueIndex;
    }

    function setExitRequestTimestamp() external onlyEtherFiNodeManagerContract {
        require(exitRequestTimestamp == 0, "Exit request was already sent.");
        exitRequestTimestamp = uint32(block.timestamp);
    }

    function markExited(uint32 _exitTimestamp) external onlyEtherFiNodeManagerContract {
        phase = VALIDATOR_PHASE.EXITED;
        exitTimestamp = _exitTimestamp;
    }

    function receiveVestedRewardsForStakers()
        external
        payable
        onlyProtocolRevenueManagerContract
    {
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

    function updateAfterPartialWithdrawal(bool _vestedAuctionFee) external {
        if (_vestedAuctionFee && _getClaimableVestedRewards() > 0) {
            vestedAuctionRewards = 0;
        }
    }

    /// @notice compute the payouts for {staking, protocol} rewards and vested auction fee to the individuals
    /// @param _stakingRewards a flag to be set if the caller wants to compute the payouts for the stkaing rewards
    /// @param _protocolRewards a flag to be set if the caller wants to compute the payouts for the protocol rewards
    /// @param _vestedAuctionFee a flag to be set if the caller wants to compute the payouts for the vested auction fee
    /// @param _SRsplits the splits for the Staking Rewards
    /// @param _SRscale the scale 
    /// @param _PRsplits the splits for the Protocol Rewards
    /// @param _PRscale the scale 
    function getRewards(bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee, 
                        IEtherFiNodesManager.RewardsSplit memory _SRsplits, uint256 _SRscale, 
                        IEtherFiNodesManager.RewardsSplit memory _PRsplits, uint256 _PRscale) 
        public view onlyEtherFiNodeManagerContract 
        returns (uint256, uint256, uint256, uint256) {
        uint256 operator;
        uint256 tnft;
        uint256 bnft;
        uint256 treasury;

        uint256[] memory tmps = new uint256[](4);
        if (_stakingRewards) {
            (tmps[0], tmps[1], tmps[2], tmps[3]) = getStakingRewards(_SRsplits, _SRscale);
            operator += tmps[0];
            tnft += tmps[1];
            bnft += tmps[2];
            treasury += tmps[3];
        }

        if (_protocolRewards) {
            (tmps[0], tmps[1], tmps[2], tmps[3]) = getProtocolRewards(_PRsplits, _PRscale);
            operator += tmps[0];
            tnft += tmps[1];
            bnft += tmps[2];
            treasury += tmps[3];
        }

        if (_vestedAuctionFee) {
            uint256 rewards = _getClaimableVestedRewards();
            uint256 toTnft = (rewards * 29) / 32;
            tnft += toTnft; // 29 / 32
            bnft += rewards - toTnft; // 3 / 32
        }

        return (operator, tnft, bnft, treasury);
    }

    /// @notice get the accrued staking rewards payouts to (toNodeOperator, toTnft, toBnft, toTreasury)
    /// @param _splits the splits for the staking rewards
    /// @param _scale the scale = SUM(_splits)
    function getStakingRewards(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) public view onlyEtherFiNodeManagerContract returns (uint256, uint256, uint256, uint256) {
        uint256 balance = address(this).balance;
        uint256 rewards = (balance > vestedAuctionRewards) ? balance - vestedAuctionRewards : 0;
        if (rewards >= 32 ether) {
            rewards -= 32 ether;
        } else if (rewards >= 8 ether) {
            // In a case of Slashing, without the Oracle, the exact staking rewards cannot be computed in this case
            // Assume no staking rewards in this case.
            rewards = 0;
        }
        (uint256 operator, uint256 tnft, uint256 bnft, uint256 treasury) = _getPayoutsBasedOnSplits(rewards, _splits, _scale);
        uint256 daysPassedSinceExitRequest = _getDaysPassedSince(exitRequestTimestamp, uint32(block.timestamp));
        if (daysPassedSinceExitRequest >= 14) {
            treasury += operator;
            operator = 0;
        }

        return (operator, tnft, bnft, treasury);
    }

    /// @notice get the accrued protocol rewards payouts to (toNodeOperator, toTnft, toBnft, toTreasury)
    /// @param _splits the splits for the protocol rewards
    /// @param _scale the scale = SUM(_splits)
    function getProtocolRewards(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) public view onlyEtherFiNodeManagerContract returns (uint256, uint256, uint256, uint256) {
        uint256 globalRevenueIndex = IProtocolRevenueManager(protocolRevenueManagerAddress()).globalRevenueIndex();
        uint256 rewards = globalRevenueIndex - localRevenueIndex;
        return _getPayoutsBasedOnSplits(rewards, _splits, _scale);
    }

    /// @notice get withdrawable balance via either 'partialWithdraw' or 'fullWithdraw'
    function getWithdrawableBalance() public view returns (uint256) {
        uint256 balance = address(this).balance;
        uint256 claimableVestedRewards = _getClaimableVestedRewards();
        if (balance + claimableVestedRewards >= vestedAuctionRewards) {
            return balance + claimableVestedRewards - vestedAuctionRewards;
        } else {
            return 0;
        }
    }

    /// @notice compute the non exit penalty for the b-nft holder
    /// @param _principal the principal for the non exit penalty (e.g., 1 ether)
    /// @param _dailyPenalty the dailty penalty for the non exit penalty
    /// @param _exitTimestamp the exit timestamp for the validator node
    function getNonExitPenaltyAmount(uint256 _principal, uint256 _dailyPenalty, uint32 _exitTimestamp) public view onlyEtherFiNodeManagerContract returns (uint256) {
        uint256 daysElapsed = _getDaysPassedSince(exitRequestTimestamp, _exitTimestamp);
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

    /// @notice Given the current balance of the ether fi node after its EXIT,
    ///         Compute the payouts to {node operator, t-nft holder, b-nft holder, treasury}
    /// @param _splits the splits for the staking rewards
    /// @param _scale the scale = SUM(_splits)
    /// @param _principal the principal for the non exit penalty (e.g., 1 ether)
    /// @param _dailyPenalty the dailty penalty for the non exit penalty
    /// returns the payouts to (toNodeOperator, toTnft, toBnft, toTreasury)
    function getFullWithdrawalPayouts(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale, uint256 _principal, uint256 _dailyPenalty) external view returns (uint256, uint256, uint256, uint256) {
        uint256 balance = address(this).balance - vestedAuctionRewards;
        require (balance >= 16 ether, "not enough balance for full withdrawal");
        require (phase == VALIDATOR_PHASE.EXITED, "validator node is not exited");

        // (toNodeOperator, toTnft, toBnft, toTreasury)
        uint256[] memory payouts = new uint256[](4);

        uint256 toBnftPrincipal;
        uint256 toTnftPrincipal;
        uint256 bnftNonExitPenalty = getNonExitPenaltyAmount(_principal, _dailyPenalty, exitTimestamp);

        if (balance > 32 ether) {
            (payouts[0], payouts[1], payouts[2], payouts[3]) = getStakingRewards(_splits, _scale);
            balance = 32 ether;
        }

        if (balance > 31.5 ether) {
            // 31.5 ether < balance <= 32 ether
            toBnftPrincipal = balance - 30 ether;
        } else if (balance > 26 ether) {
            // 26 ether < balance <= 31.5 ether
            toBnftPrincipal = 1.5 ether;
        } else if (balance > 25.5 ether) {
            // 25.5 ether < balance <= 26 ether
            toBnftPrincipal = 1.5 ether - (26 ether - balance);
        } else {
            // balance <= 25.5 ether
            toBnftPrincipal = 1 ether;
        }
        toTnftPrincipal = balance - toBnftPrincipal;
        
        payouts[1] += toTnftPrincipal;
        payouts[2] += toBnftPrincipal;

        payouts[2] -= bnftNonExitPenalty;

        if (bnftNonExitPenalty > 0.5 ether) {
            payouts[0] += 0.5 ether;
            payouts[3] += (bnftNonExitPenalty - 0.5 ether);
        } else {
            payouts[0] += bnftNonExitPenalty;
        }

        require(payouts[0] + payouts[1] + payouts[2] + payouts[3] == address(this).balance - vestedAuctionRewards, "Incorrect Amount");
        return (payouts[0], payouts[1], payouts[2], payouts[3]);
    }

    function _getClaimableVestedRewards() internal view returns (uint256) {
        if (vestedAuctionRewards == 0) {
            return 0;
        }
        uint256 vestingPeriodInDays = IProtocolRevenueManager(protocolRevenueManagerAddress()).auctionFeeVestingPeriodForStakersInDays(); // ProtocolRevenueManager's 'auctionFeeVestingPeriodForStakersInDays'
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

    function _getPayoutsBasedOnSplits(uint256 _totalAmount, IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) internal view returns (uint256, uint256, uint256, uint256) {
        require(_splits.nodeOperator + _splits.tnft + _splits.bnft + _splits.treasury == _scale, "Incorrect Splits");
        uint256 operator = (_totalAmount * _splits.nodeOperator) / _scale;
        uint256 tnft = (_totalAmount * _splits.tnft) / _scale;
        uint256 bnft = (_totalAmount * _splits.bnft) / _scale;
        uint256 treasury = _totalAmount - (bnft + tnft + operator);
        return (operator, tnft, bnft, treasury);
    }

    function etherfiNodesManagerAddress() internal view returns (address) {
        // TODO: Replace it with the actual address
        // return 0x...
        return etherfiNodesManager;
    }

    function protocolRevenueManagerAddress() internal view returns (address) {
        // TODO: Replace it with the actual address
        // return 0x...
        return protocolRevenueManager;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyEtherFiNodeManagerContract() {
        require(
            msg.sender == etherfiNodesManager,
            "Only EtherFiNodeManager Contract"
        );
        _;
    }

    // TODO
    modifier onlyProtocolRevenueManagerContract() {
        require(
            msg.sender == protocolRevenueManager,
            "Only protocol revenue manager contract function"
        );
        _;
    }
}
