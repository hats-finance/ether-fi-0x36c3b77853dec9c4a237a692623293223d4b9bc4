// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IEtherFiNode.sol";
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
    uint32 public stakingStartTimestamp;
    uint32 public exitRequestTimestamp;
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

    function _getClaimableVestedRewards() internal returns (uint256) {
        uint256 vestingPeriodInDays = IProtocolRevenueManager(protocolRevenueManagerAddress).auctionFeeVestingPeriodForStakersInDays();
        uint256 timeElapsed = uint32(block.timestamp) - stakingStartTimestamp;
        uint256 SECONDS_PER_DAY = 24 * 3600;
        uint256 daysElapsed = vestingPeriodInDays * SECONDS_PER_DAY;
        if (timeElapsed >= vestingPeriodInDays * SECONDS_PER_DAY) {
            uint256 _vestedAuctionRewards = vestedAuctionRewards;
            // vestedAuctionRewards = 0;
            return _vestedAuctionRewards;
        } else {
            return 0;
        }
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
