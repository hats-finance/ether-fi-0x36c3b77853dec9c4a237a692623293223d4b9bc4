// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../MembershipManager.sol";
import "../LiquidityPool.sol";

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
    * @param _tierDepositsLength the length of the deposit array in the membership manager
    * @param _membershipManager the address of the membership manager
    * @param _liquidityPool the address of the liquidity pool
    * @return globalIndex A uint96 array containing the updated global index for each tier.
    * @return adjustedShares A uint128 array containing the updated shares for each tier reflecting the amount of staked ETH in the liquidity pool.
    */
    function calculateGlobalIndex(uint256 _tierDepositsLength, address _membershipManager, address _liquidityPool) public view returns (uint96[] memory, uint128[] memory) {
        
        MembershipManager membershipManager = MembershipManager(payable(_membershipManager));
        LiquidityPool liquidityPool = LiquidityPool(payable(_liquidityPool));

        uint96[] memory globalIndex = new uint96[](_tierDepositsLength);
        uint128[] memory adjustedShares = new uint128[](_tierDepositsLength);
        uint256[] memory weightedTierRewards = new uint256[](_tierDepositsLength);
        uint256[] memory tierRewards = new uint256[](_tierDepositsLength);
        uint256 sumTierRewards = 0;
        uint256 sumWeightedTierRewards = 0;
        for (uint256 i = 0; i < weightedTierRewards.length; i++) {
            (uint128 amounts, uint128 shares) = membershipManager.tierDeposits(i);
            (uint96 rewardsGlobalIndex, uint40 requiredTierPoints, uint24 weight,) = membershipManager.tierData(i);

            uint256 rebasedAmounts = liquidityPool.amountForShare(shares);
            if (rebasedAmounts >= amounts) {
                tierRewards[i] = rebasedAmounts - amounts;
                weightedTierRewards[i] = weight * tierRewards[i];
            }
            globalIndex[i] = rewardsGlobalIndex;
            adjustedShares[i] = shares;

            sumTierRewards += tierRewards[i];
            sumWeightedTierRewards += weightedTierRewards[i];
        }

        if (sumWeightedTierRewards > 0) {
            for (uint256 i = 0; i < weightedTierRewards.length; i++) {
                (uint128 amounts, uint128 shares) = membershipManager.tierDeposits(i);
                if (shares > 0) {
                    uint256 rescaledTierRewards = weightedTierRewards[i] * sumTierRewards / sumWeightedTierRewards;
                    uint256 delta = 1 ether * rescaledTierRewards / shares;

                    if (uint256(globalIndex[i]) + uint256(delta) > type(uint96).max) revert IntegerOverflow();

                    globalIndex[i] += uint96(delta);
                    adjustedShares[i] = uint128(liquidityPool.sharesForAmount(amounts));
                }
            }
        }

        return (globalIndex, adjustedShares);
    }
}