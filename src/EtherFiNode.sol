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
    
    // TODO: reduce the size of these varaibles
    uint256 public localRevenueIndex;
    uint256 public vestedAuctionRewards;
    string public ipfsHashForEncryptedValidatorKey;
    uint32 public exitRequestTimestamp;
    uint32 public exitTimestamp;
    uint32 public stakingStartTimestamp;
    VALIDATOR_PHASE public phase;

    bool private initialized = false;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    function initialize() public {
        require(initialized == false, "already initialised");
        initialized = true;
        stakingStartTimestamp = uint32(block.timestamp);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {}

    /// @notice Set the validator phase
    /// @param _phase the new phase
    function setPhase(VALIDATOR_PHASE _phase) external onlyEtherFiNodeManagerContract {
        phase = _phase;
    }

    /// @notice Set the deposit data
    /// @param _ipfsHash the deposit data
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfsHash) external onlyEtherFiNodeManagerContract {
        ipfsHashForEncryptedValidatorKey = _ipfsHash;
    }

    function setLocalRevenueIndex(uint256 _localRevenueIndex) payable external onlyEtherFiNodeManagerContract {
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
        require(vestedAuctionRewards == 0, "already received the vested auction fee reward");
        vestedAuctionRewards = msg.value;
    }

    function processVestedAuctionFeeWithdrawal() external {
        if (_getClaimableVestedRewards() > 0) {
            vestedAuctionRewards = 0;
        }
    }

    function moveRewardsToManager(uint256 _amount) external onlyEtherFiNodeManagerContract {
        (bool sent, ) = payable(etherfiNodesManagerAddress()).call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function withdrawFunds(
        address _treasury, uint256 _treasuryAmount,
        address _operator, uint256 _operatorAmount,
        address _tnftHolder, uint256 _tnftAmount,
        address _bnftHolder, uint256 _bnftAmount
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

    /// @notice compute the payouts for {staking, protocol} rewards and vested auction fee to the individuals
    /// @param _stakingRewards a flag to be set if the caller wants to compute the payouts for the stkaing rewards
    /// @param _protocolRewards a flag to be set if the caller wants to compute the payouts for the protocol rewards
    /// @param _vestedAuctionFee a flag to be set if the caller wants to compute the payouts for the vested auction fee
    /// @param _SRsplits the splits for the Staking Rewards
    /// @param _SRscale the scale 
    /// @param _PRsplits the splits for the Protocol Rewards
    /// @param _PRscale the scale 
    /// 
    /// @return toNodeOperator  the payout to the Node Operator
    /// @return toTnft          the payout to the T-NFT holder
    /// @return toBnft          the payout to the B-NFT holder
    /// @return toTreasury      the payout to the Treasury
    function getRewardsPayouts(bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee, 
                        IEtherFiNodesManager.RewardsSplit memory _SRsplits, uint256 _SRscale, 
                        IEtherFiNodesManager.RewardsSplit memory _PRsplits, uint256 _PRscale) 
        public view onlyEtherFiNodeManagerContract 
        returns (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) {
        uint256 operator;
        uint256 tnft;
        uint256 bnft;
        uint256 treasury;

        uint256[] memory tmps = new uint256[](4);
        if (_stakingRewards) {
            (tmps[0], tmps[1], tmps[2], tmps[3]) = getStakingRewardsPayouts(_SRsplits, _SRscale);
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
    /// 
    /// @return toNodeOperator  the payout to the Node Operator
    /// @return toTnft          the payout to the T-NFT holder
    /// @return toBnft          the payout to the B-NFT holder
    /// @return toTreasury      the payout to the Treasury
    function getStakingRewardsPayouts(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) 
        public view onlyEtherFiNodeManagerContract 
        returns (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) {
        uint256 balance = address(this).balance;
        uint256 rewards = (balance > vestedAuctionRewards) ? balance - vestedAuctionRewards : 0;
        if (rewards >= 32 ether) {
            rewards -= 32 ether;
        } else if (rewards >= 8 ether) {
            // In a case of Slashing, without the Oracle, the exact staking rewards cannot be computed in this case
            // Assume no staking rewards in this case.
            rewards = 0;
        }
        (uint256 operator, uint256 tnft, uint256 bnft, uint256 treasury) = calculatePayouts(rewards, _splits, _scale);
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
    /// 
    /// @return toNodeOperator  the payout to the Node Operator
    /// @return toTnft          the payout to the T-NFT holder
    /// @return toBnft          the payout to the B-NFT holder
    /// @return toTreasury      the payout to the Treasury
    function getProtocolRewards(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) 
        public view onlyEtherFiNodeManagerContract 
        returns (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) {
        if (localRevenueIndex == 0) {
            return (0, 0, 0, 0);
        }
        uint256 globalRevenueIndex = IProtocolRevenueManager(protocolRevenueManagerAddress()).globalRevenueIndex();
        uint256 rewards = globalRevenueIndex - localRevenueIndex;
        return calculatePayouts(rewards, _splits, _scale);
    }

    /// @notice compute the non exit penalty for the b-nft holder
    /// @param _principal the principal for the non exit penalty (e.g., 1 ether)
    /// @param _dailyPenalty the dailty penalty for the non exit penalty
    /// @param _exitTimestamp the exit timestamp for the validator node
    function getNonExitPenalty(uint256 _principal, uint256 _dailyPenalty, uint32 _exitTimestamp) 
        public view onlyEtherFiNodeManagerContract 
        returns (uint256) {
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
    /// 
    /// @return toNodeOperator  the payout to the Node Operator
    /// @return toTnft          the payout to the T-NFT holder
    /// @return toBnft          the payout to the B-NFT holder
    /// @return toTreasury      the payout to the Treasury
    function getFullWithdrawalPayouts(IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale, uint256 _principal, uint256 _dailyPenalty) 
        external view returns (uint256 toNodeOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) {
        require (address(this).balance >= 16 ether, "not enough balance for full withdrawal");
        require (phase == VALIDATOR_PHASE.EXITED, "validator node is not exited");
        uint256 balance = address(this).balance - vestedAuctionRewards;

        // (toNodeOperator, toTnft, toBnft, toTreasury)
        uint256[] memory payouts = new uint256[](4);

        // Compute the payouts for the staking rewards (which is exceeding amount above 32 ETH)
        if (balance > 32 ether) {
            (payouts[0], payouts[1], payouts[2], payouts[3]) = getRewardsPayouts(true, false, true, _splits, _scale, _splits, _scale);
            balance = 32 ether;
        }

        // Compute the payouts for the principals to {B, T}-NFTs
        uint256 toBnftPrincipal;
        uint256 toTnftPrincipal;
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
            // 16 ether <= balance <= 25.5 ether
            toBnftPrincipal = 1 ether;
        }
        toTnftPrincipal = balance - toBnftPrincipal;
        payouts[1] += toTnftPrincipal;
        payouts[2] += toBnftPrincipal;

        // Deduct the NonExitPenalty from the payout to the B-NFT
        uint256 bnftNonExitPenalty = getNonExitPenalty(_principal, _dailyPenalty, exitTimestamp);
        payouts[2] -= bnftNonExitPenalty;

        // While the NonExitPenalty keeps growing till 1 ether,
        //  the incentive to the node operator stops growing at 0.5 ether 
        //  the rest goes to the treasury
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
        uint256 vestingPeriodInDays = IProtocolRevenueManager(protocolRevenueManagerAddress()).auctionFeeVestingPeriodForStakersInDays();
        uint256 daysPassed = _getDaysPassedSince(stakingStartTimestamp, uint32(block.timestamp));
        if (daysPassed >= vestingPeriodInDays) {
            return vestedAuctionRewards;
        } else {
            return 0;
        }
    }

    function _getDaysPassedSince(uint32 _startTimestamp, uint32 _endTimestamp) internal view returns (uint256) {
        uint256 timeElapsed = _endTimestamp - _startTimestamp;
        return uint256(timeElapsed / (24 * 3600));
    }

    function calculatePayouts(uint256 _totalAmount, IEtherFiNodesManager.RewardsSplit memory _splits, uint256 _scale) public view returns (uint256, uint256, uint256, uint256) {
        require(_splits.nodeOperator + _splits.tnft + _splits.bnft + _splits.treasury == _scale, "Incorrect Splits");
        uint256 operator = (_totalAmount * _splits.nodeOperator) / _scale;
        uint256 tnft = (_totalAmount * _splits.tnft) / _scale;
        uint256 bnft = (_totalAmount * _splits.bnft) / _scale;
        uint256 treasury = _totalAmount - (bnft + tnft + operator);
        return (operator, tnft, bnft, treasury);
    }

    // GOERLI Address: 0x8a4DEa011d9C0F0aB4535Fce9EbC6eea9002b225
    // LOCAL TESTNET Address: 0xb2c1ca19c453c22e8A4438C269192E9F57f207B9
    function etherfiNodesManagerAddress() internal view returns (address) {
        /// TODO: Replace it with the actual address
        // This is  the Local testnet address.
        // Replace with mainnet address before deployment 
        return  0xb2c1ca19c453c22e8A4438C269192E9F57f207B9;
    }

    // GOERLI Address: 0xc8556F65b9a3113A4Ad03bFba219e2FE9261f9fC
    // LOCAL TESTNET Address: 0x5cc5EF423D89fab901F79621A071bfB342a5FC47
    function protocolRevenueManagerAddress() internal pure returns (address) {
        // TODO: Replace it with the actual address
        // This is  the Local testnet address.
        // Replace with mainnet address before deployment 
        return 0x5cc5EF423D89fab901F79621A071bfB342a5FC47;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyEtherFiNodeManagerContract() {
        require(
            msg.sender == etherfiNodesManagerAddress(),
            "Only EtherFiNodeManager Contract"
        );
        _;
    }

    // TODO
    modifier onlyProtocolRevenueManagerContract() {
        require(
            msg.sender == protocolRevenueManagerAddress(),
            "Only protocol revenue manager contract function"
        );
        _;
    }
}
