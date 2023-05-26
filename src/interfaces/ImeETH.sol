// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ImeETH {

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
        uint8  _dummy; // a place-holder for future usage
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
    function initialize(string calldata _newURI, address _eEthAddress, address _liquidityPoolAddress) external;

    function wrapEthForEap(uint256 _amount, uint256 _amountForPoint, uint256 _snapshotEthAmount, uint256 _points, bytes32[] calldata _merkleProof) external payable returns (uint256);
    function wrapEth(uint256 _amount, uint256 _amountForPoint, bytes32[] calldata _merkleProof) external payable returns (uint256);
    function wrapEEth(uint256 _amount, uint256 _amountForPoint) external returns (uint256);

    function topUpDepositWithEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints, bytes32[] calldata _merkleProof) external payable;
    function topUpDepositWithEEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints) external;

    function unwrapForEEth(uint256 _tokenId, uint256 _amount) external;
    function unwrapForEth(uint256 _tokenId, uint256 _amount) external;

    function stakeForPoints(uint256 _tokenId, uint256 _amount) external;
    function unstakeForPoints(uint256 _tokenId, uint256 _amount) external;

    function claimTier(uint256 _tokenId) external;
    function claimPoints(uint256 _tokenId) external;
    function claimStakingRewards(uint256 _tokenId) external;

    // Getter functions
    function valueOf(uint256 _tokenId) external view returns (uint256);
    function loyaltyPointsOf(uint256 _tokenId) external view returns (uint40);
    function tierPointsOf(uint256 _tokenId) external view returns (uint40);
    function tierOf(uint256 _tokenId) external view returns (uint8);
    function claimableTier(uint256 _tokenId) external view returns (uint8);
    function accruedLoyaltyPointsOf(uint256 _tokenId) external view returns (uint40);
    function accruedTierPointsOf(uint256 _tokenId) external view returns (uint40);
    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) external view returns (bool);
    function isWithdrawable(uint256 _tokenId, uint256 _withdrawalAmount) external view returns (bool);
    function allTimeHighDepositOf(uint256 _tokenId) external view returns (uint256);
    function convertEapPoints(uint256 _eapPoints, uint256 _ethAmount) external view returns (uint40, uint40);

    function getImplementation() external view returns (address);

    // only Owner
    function updatePointsBoostFactor(uint16 _newPointsBoostFactor) external;
    function updatePointsGrowthRate(uint16 _newPointsGrowthRate) external;
    function distributeStakingRewards() external;
    function addNewTier(uint40 _requiredTierPoints, uint24 _weight) external returns (uint256);
    function setPoints(uint256 _tokenId, uint40 _loyaltyPoints, uint40 _tierPoints) external;
    function setUpForEap(bytes32 _newMerkleRoot, uint64[] calldata _requiredEapPointsPerEapDeposit) external;
    function setMinDepositWei(uint56 _value) external;
    function setMaxDepositTopUpPercent(uint8 _percent) external;
}
