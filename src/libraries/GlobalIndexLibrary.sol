// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../MembershipManager.sol";
import "../LiquidityPool.sol";
import "forge-std/console.sol";

library globalIndexLibrary {
    
    error IntegerOverflow();

    /**
    * @dev This function calculates the global index and adjusted shares for each tier used for reward distribution.
    *
    * The function performs the following steps:
    * 1. Iterates over each tier, computing rebased amounts, tier rewards, weighted tier rewards.
    * 2. Sums all the tier rewards and the weighted tier rewards.
    * 3. If there are any weighted tier rewards, it iterates over each tier to perform the following actions:
    *    a. Computes the amounts eligible for rewards.
    *    b. If there are amounts eligible for rewards, 
    *       it calculates rescaled tier rewards and updates the global index and adjusted shares for the tier.
    *
    * The rescaling of tier rewards is done based on the weight of each tier. 
    *
    * @notice This function essentially pools all the staking rewards across tiers and redistributes them proportional to the tier weights
    * @param _membershipManager the address of the membership manager
    * @param _liquidityPool the address of the liquidity pool
    * @return globalIndex A uint96 array containing the updated global index for each tier.
    * @return adjustedShares A uint128 array containing the updated shares for each tier reflecting the amount of staked ETH in the liquidity pool.
    */
    function calculateGlobalIndex(address _membershipManager, address _liquidityPool) public view returns (uint96[] memory, uint128[] memory) {
        MembershipManager membershipManager = MembershipManager(payable(_membershipManager));
        LiquidityPool liquidityPool = LiquidityPool(payable(_liquidityPool));

        (uint256[] memory tierRewards, uint24[] memory tierWeights) = calculateRewardsPerTierV0(_membershipManager, _liquidityPool);
        uint256[] memory rescaledTierRewards = calculateRescaledTierRewards(tierRewards, tierWeights);

        uint96[] memory globalIndex = new uint96[](rescaledTierRewards.length);
        uint128[] memory adjustedShares = new uint128[](rescaledTierRewards.length);

        for (uint256 i = 0; i < adjustedShares.length; i++) {
            (uint128 amounts, uint128 shares) = membershipManager.tierDeposits(i);
            (uint96 rewardsGlobalIndex, uint40 requiredTierPoints, uint24 weight,) = membershipManager.tierData(i);
            globalIndex[i] = rewardsGlobalIndex;
            if (shares > 0) {
                uint256 delta = 1 ether * rescaledTierRewards[i] / shares;
                if (uint256(globalIndex[i]) + uint256(delta) > type(uint96).max) revert IntegerOverflow();

                globalIndex[i] += uint96(delta);
                adjustedShares[i] = uint128(liquidityPool.sharesForAmount(amounts));
            }
        }

        return (globalIndex, adjustedShares);
    }

    function calculateRewardsPerTierV0(address _membershipManager, address _liquidityPool) public view returns (uint256[] memory, uint24[] memory) {
        MembershipManager membershipManager = MembershipManager(payable(_membershipManager));
        LiquidityPool liquidityPool = LiquidityPool(payable(_liquidityPool));

        uint256 numberOfTiers = membershipManager.numberOfTiers();
        uint256[] memory tierRewards = new uint256[](numberOfTiers);
        uint24[] memory tierWeights = new uint24[](numberOfTiers);

        for (uint256 i = 0; i < numberOfTiers; i++) {
            (uint128 amounts, uint128 shares) = membershipManager.tierDeposits(i);
            (uint96 rewardsGlobalIndex, uint40 requiredTierPoints, uint24 weight,) = membershipManager.tierData(i);

            uint256 rebasedAmounts = liquidityPool.amountForShare(shares);
            if (rebasedAmounts >= amounts) {
                tierRewards[i] = rebasedAmounts - amounts;
                tierWeights[i] = weight;
            }
        }

        return (tierRewards, tierWeights);
    }
    
    // Compute `rescaledTierRewards` for each tier from `tierRewards` and `weight`
    function calculateRescaledTierRewards(uint256[] memory tierRewards, uint24[] memory tierWeights) public view returns (uint256[] memory) {
        uint256[] memory weightedTierRewards = new uint256[](tierRewards.length);
        uint256[] memory rescaledTierRewards = new uint256[](tierRewards.length);
        uint256 sumTierRewards = 0;
        uint256 sumWeightedTierRewards = 0;

        for (uint256 i = 0; i < tierRewards.length; i++) {
            weightedTierRewards[i] = tierWeights[i] * tierRewards[i];

            sumTierRewards += tierRewards[i];
            sumWeightedTierRewards += weightedTierRewards[i];
        }

        if (sumWeightedTierRewards > 0) {
            for (uint256 i = 0; i < tierRewards.length; i++) {
                rescaledTierRewards[i] = weightedTierRewards[i] * sumTierRewards / sumWeightedTierRewards;
            }
        }

        return rescaledTierRewards;
    }

    function calculateRewardsPerTierV1(address _membershipManager, address _liquidityPool, uint256 _ethRewardsAmountPerEEthShare) public view returns (uint256[] memory, uint24[] memory) {
        MembershipManager membershipManager = MembershipManager(payable(_membershipManager));
        LiquidityPool liquidityPool = LiquidityPool(payable(_liquidityPool));

        uint256 numberOfTiers = membershipManager.numberOfTiers();
        uint256[] memory tierRewards = new uint256[](numberOfTiers);
        uint24[] memory tierWeights = new uint24[](numberOfTiers);

        for (uint256 i = 0; i < numberOfTiers; i++) {
            (uint128 totalPooledEEthShares, uint128 totalVaultShares) = membershipManager.tierVaults(i);
            (,, uint24 weight,) = membershipManager.tierData(i);

            tierRewards[i] = _ethRewardsAmountPerEEthShare * totalPooledEEthShares / 1 ether;
            tierWeights[i] = weight;
        }

        return (tierRewards, tierWeights);
    }

    // TODO - rewrite it later more efficiently
    function calculateVaultEEthShares(address _membershipManager, address _liquidityPool, uint256 _shareValuePerEthBeforeRebase, uint256 _shareValuePerEthAfterRebase) public view returns (uint128[] memory) {
        MembershipManager membershipManager = MembershipManager(payable(_membershipManager));
        LiquidityPool liquidityPool = LiquidityPool(payable(_liquidityPool));

        uint256 numberOfTiers = membershipManager.numberOfTiers();
        uint128[] memory vaultTotalPooledEEthShares = new uint128[](numberOfTiers);

        uint256 ethRewardsAmountPerEEthShare = (_shareValuePerEthAfterRebase - _shareValuePerEthBeforeRebase);
        (uint256[] memory tierRewards, uint24[] memory tierWeights) = calculateRewardsPerTierV1(_membershipManager, _liquidityPool, ethRewardsAmountPerEEthShare);
        uint256[] memory rescaledTierRewards = calculateRescaledTierRewards(tierRewards, tierWeights);

        for (uint256 i = 0; i < numberOfTiers; i++) {
            (uint128 totalPooledEEthShares, ) = membershipManager.tierVaults(i);
            uint256 prevEthAmount = _shareValuePerEthBeforeRebase * totalPooledEEthShares / 1 ether;
            uint256 newEthAmount = prevEthAmount + rescaledTierRewards[i];
            vaultTotalPooledEEthShares[i] = uint128(liquidityPool.sharesForAmount(newEthAmount));
        }
        return vaultTotalPooledEEthShares;
    }
}