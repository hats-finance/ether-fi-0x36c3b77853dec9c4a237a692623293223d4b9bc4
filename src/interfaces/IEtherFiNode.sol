// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";

interface IEtherFiNode {
    //The state of the validator
    enum VALIDATOR_PHASE {
        STAKE_DEPOSITED,
        LIVE,
        EXITED,
        CANCELLED
    }

    function setPhase(VALIDATOR_PHASE _phase) external;
    function setIpfsHashForEncryptedValidatorKey(string calldata _ipfs) external;
    function setLocalRevenueIndex(uint256 _localRevenueIndex) external;
    function setExitRequestTimestamp() external;
    function markExited() external;
    function receiveVestedRewardsForStakers() external payable;

    function phase() external view returns (VALIDATOR_PHASE);
    function ipfsHashForEncryptedValidatorKey() external view returns (string memory);
    function localRevenueIndex() external view returns (uint256);
    function stakingStartTimestamp() external view returns (uint32);
    function exitRequestTimestamp() external view returns (uint32);
    function exitTimestamp() external view returns (uint32);
    function vestedAuctionRewards() external view returns (uint256);
    function getAccruedStakingRewards() external view returns (uint256);

    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external;

    function receiveProtocolRevenue(uint256 _globalRevenueIndex) payable external;
}
