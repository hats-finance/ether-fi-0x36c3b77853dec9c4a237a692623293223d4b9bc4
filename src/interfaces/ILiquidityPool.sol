// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IStakingManager.sol";

interface ILiquidityPool {
    function numPendingDeposits() external view returns (uint32);
    function totalValueOutOfLp() external view returns (uint128);
    function totalValueInLp() external view returns (uint128);
    function getTotalEtherClaimOf(address _user) external view returns (uint256);
    function getTotalPooledEther() external view returns (uint256);
    function sharesForAmount(uint256 _amount) external view returns (uint256);
    function sharesForWithdrawalAmount(uint256 _amount) external view returns (uint256);
    function amountForShare(uint256 _share) external view returns (uint256);
    function eEthliquidStakingOpened() external view returns (bool);

    function deposit(address _user, bytes32[] calldata _merkleProof) external payable;
    function deposit(address _user, address _recipient, bytes32[] calldata _merkleProof) external payable;
    function withdraw(address _recipient, uint256 _amount) external;
    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);
    function requestMembershipNFTWithdraw(address recipient, uint256 amount) external returns (uint256);

    function batchDepositAsBnftHolder(uint256[] calldata _candidateBidIds, bytes32[] calldata _merkleProof, uint256 _index) external payable returns (uint256[] memory);
    function batchRegisterAsBnftHolder(bytes32 _depositRoot, uint256[] calldata _validatorIds, IStakingManager.DepositData[] calldata _depositData, bytes[] calldata signaturesForApprovalDeposit) external;
    function batchCancelDeposit(uint256[] calldata _validatorIds) external;
    function sendExitRequests(uint256[] calldata _validatorIds) external;

    function openEEthLiquidStaking() external;
    function closeEEthLiquidStaking() external;

    function rebase(uint256 _tvl, uint256 _balanceInLp) external;
    function setTokenAddress(address _eETH) external;
    function setStakingManager(address _address) external;
    function setEtherFiNodesManager(address _nodeManager) external;
    function setMembershipManager(address _address) external;
    function setTnft(address _address) external;
    function setWithdrawRequestNFT(address _address) external; 
    
    function updateAdmin(address _newAdmin) external;
    function updateBNftTreasury(address _newTreasury) external; 

    enum SourceOfFunds {
        UNDEFINED,
        EETH,
        ETHER_FAN
    }

    struct FundStatistics {
        uint256 amountOfFundsInPool;
        uint128 numberOfValidators;
        uint128 targetWeight;
    }

    // Necessary to preserve "statelessness" of dutyForWeek().
    // Handles case where new users join/leave holder list during an active slot
    struct HoldersUpdate {
        uint128 timestamp;
        uint128 startOfSlotNumOwners;
    }
}
