// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMembershipManager {

    struct TokenDeposit {
        uint128 amounts;
        uint128 amountStakedForPoints;
    }

    struct TokenData {
        uint96 rewardsLocalIndex;
        uint40 baseLoyaltyPoints;
        uint40 baseTierPoints;
        uint32 prevPointsAccrualTimestamp;
        uint32 prevTopUpTimestamp;
        uint8  tier;
        uint8  __gap;
    }

    struct TierDeposit {
        uint128 shares;
        uint128 amounts;
    }

    struct TierData {
        uint96 rewardsGlobalIndex;
        uint96 amountStakedForPoints;
        uint40 requiredTierPoints;
        uint24 weight;
    }

    // State-changing functions
    function initialize(address _eEthAddress, address _liquidityPoolAddress, address _membershipNft, address _treasury, address _protocolRevenueManager) external;

    function wrapEthForEap(uint256 _amount, uint256 _amountForPoint, uint256 _snapshotEthAmount, uint256 _points, bytes32[] calldata _merkleProof) external payable returns (uint256);
    function wrapEth(uint256 _amount, uint256 _amountForPoint, bytes32[] calldata _merkleProof) external payable returns (uint256);

    function topUpDepositWithEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints, bytes32[] calldata _merkleProof) external payable;

    function unwrapForEth(uint256 _tokenId, uint256 _amount) external;
    function withdrawAndBurnForEth(uint256 _tokenId) external;

    function stakeForPoints(uint256 _tokenId, uint256 _amount) external;
    function unstakeForPoints(uint256 _tokenId, uint256 _amount) external;

    function claimTier(uint256 _tokenId) external;
    function claimPoints(uint256 _tokenId) external;
    function claimStakingRewards(uint256 _tokenId) external;

    // Getter functions
    function tokenDeposits(uint256) external view returns (uint128, uint128);
    function tokenData(uint256) external view returns (uint96, uint40, uint40, uint32, uint32, uint8, uint8);
    function tierData(uint256) external view returns (uint96, uint96, uint40, uint24);

    function rewardsGlobalIndex(uint8 _tier) external view returns (uint256);
    function allTimeHighDepositAmount(uint256 _tokenId) external view returns (uint256);
    function tierForPoints(uint40 _tierPoints) external view returns (uint8);
    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) external view returns (bool);
    function pointsBoostFactor() external view returns (uint16);
    function pointsGrowthRate() external view returns (uint16);
    function maxDepositTopUpPercent() external view returns (uint8);
    function calculateGlobalIndex() external view returns (uint96[] memory, uint128[] memory);

    function getImplementation() external view returns (address);

    // only Owner
    function setWithdrawalLockBlocks(uint32 _blocks) external;
    function updatePointsParams(uint16 _newPointsBoostFactor, uint16 _newPointsGrowthRate) external;
    function distributeStakingRewards() external;
    function addNewTier(uint40 _requiredTierPoints, uint24 _weight) external returns (uint256);
    function updateTier(uint8 _tier, uint40 _requiredTierPoints, uint24 _weight) external;
    function setPoints(uint256 _tokenId, uint40 _loyaltyPoints, uint40 _tierPoints) external;
    function setMinDepositWei(uint56 _value) external;
    function setMaxDepositTopUpPercent(uint8 _percent) external;
    function withdrawFees(uint256 _amount) external;
}
