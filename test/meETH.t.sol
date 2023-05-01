// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract meEthTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    function setUp() public {
        setUpTests();
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        eETHInstance.approve(address(meEthInstance), 100 ether);
        vm.stopPrank();

        // TODO: Find a proper way to do this approval
        vm.startPrank(address(meEthInstance));
        eETHInstance.approve(address(meEthInstance), 100 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        eETHInstance.approve(address(meEthInstance), 100 ether);
        vm.stopPrank();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.startPrank(owner);
        meEthInstance.addNewTier(0, 1);
        meEthInstance.addNewTier(14 * 1 ether, 1);
        meEthInstance.addNewTier(28 * 1 ether, 1);
        meEthInstance.addNewTier(42 * 1 ether, 1);
        meEthInstance.addNewTier(56 * 1 ether, 1);
        vm.stopPrank();
    }

    function test_MembershipTier() public {
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);

        // Alice wraps 1 eETH to 1 weEth
        meEthInstance.wrap(1 ether);

        assertEq(meEthInstance.pointOf(alice), 0);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 0);
        assertEq(meEthInstance.claimableTier(alice), 0);

        // For the first membership period, Alice earns points
        // But, the earned points are not eligible for the membership tier during that period
        // Those points will become eligible to claim the tier during the next period
        skip(27 days);
        assertEq(meEthInstance.pointOf(alice), 27 * 1 ether);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 0);
        assertEq(meEthInstance.claimableTier(alice), 0);
        assertEq(meEthInstance.tierOf(alice), 0);

        // Now, after a month (= 28 days), Alice's earned points are eligible for the membership tier
        // Alice's claimable tier is 2 while the current tier is still 0
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 28 * 1 ether);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 28 * 1 ether);
        assertEq(meEthInstance.claimableTier(alice), 2);
        assertEq(meEthInstance.tierOf(alice), 0);

        // Alice sees that she can claim her tier 2, which is higher than her current tier 0
        // By calling 'updateTier', Alice's tier gets upgraded to the tier 2
        meEthInstance.updateTier(alice);
        assertEq(meEthInstance.tierOf(alice), 2);

        // Alice unwraps 0.5 meETH (which is 50% of her meETH holdings)
        // Alice gets penalized for her points and her tier is updated accordingly
        meEthInstance.unwrap(0.5 ether);

        assertEq(meEthInstance.pointOf(alice), 28 * 1 ether * 50 / 100);
        assertEq(meEthInstance.claimableTier(alice), 1);
        assertEq(meEthInstance.tierOf(alice), 1);
        uint256 aliceTier = meEthInstance.tierOf(alice);

        meEthInstance.wrap(4.5 ether);
        assertEq(meEthInstance.lockedAmount(alice), 0);
        assertEq(meEthInstance.balanceOf(alice), 5 ether);

        // Alice locks 4 eETH among 5 eETH to earn more points!
        // Only the rest 1 eETH is eligible to receive the staking + boosting rewards.
        meEthInstance.tradeStakingRewardsForPoints(4 ether);
        assertEq(meEthInstance.lockedAmount(alice), 4 ether);
        assertEq(meEthInstance.balanceOf(alice), 5 ether);

        vm.stopPrank();
        
        // 10 ether --> 11 ether
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(1 ether);
        assertEq(eETHInstance.totalSupply(), 11 ether);
        vm.stopPrank();

        // The previously locked 4 eETH (by Alice) earned 0.4 ether
        meEthInstance.harvestSacrificedStakingRewards(aliceTier);
        assertEq(meEthInstance.eEthRewardsPotAmountPerTier(aliceTier), 0.4 ether);

        // The harvested 0.4 eETH is distributed to Alice over the next period 
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0);
        skip(28 days);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0.4 ether);
 
        // Alice's
        // - 1 eETH -> 1 eETH + 0.1 eETH (staking rewards) + 0.4 eETH (boosted rewards)
        // - 4 eETH -> 4 eETH
        // In total, 5 eETH -> 5.5 eETH
        assertEq(meEthInstance.balanceOf(alice), 5.5 ether);
        meEthInstance.claimBoostedStakingRewards(alice);
        assertEq(meEthInstance.balanceOf(alice), 5.5 ether - 1); // rounding error
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0);

        // No more boosted rewards without harvesting!
        skip(14 days);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0);
    }

    function test_BoostedRewards() public {
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        meEthInstance.wrap(5 ether);
        meEthInstance.tradeStakingRewardsForPoints(4 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 10 ether}(bob, bobProof);
        meEthInstance.wrap(5 ether);
        vm.stopPrank();

        assertEq(meEthInstance.tierOf(alice), meEthInstance.tierOf(bob));
        uint256 tier = meEthInstance.tierOf(alice);

        // 20 ether --> 22 ether
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(2 ether);
        assertEq(eETHInstance.totalSupply(), 22 ether);
        vm.stopPrank();

        // The previously locked 4 eETH (by Alice) earned 0.4 ether
        meEthInstance.harvestSacrificedStakingRewards(tier);
        assertEq(meEthInstance.eEthRewardsPotAmountPerTier(tier), 0.4 ether);

        // The harvested 0.4 eETH is distributed to {Alice, Bob} over the next period 
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(bob), 0);
        skip(28 days);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0.066666666666666666 ether); // 0.4 ether * 1 / (1 + 5)
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(bob), 0.333333333333333330 ether); // (0.4 ether * 5 / (1 + 5)

        // The rewards do not grow further after 28 days :) unless another 'harvestSacrificedStakingRewards' is performed
        skip(28 days);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0.066666666666666666 ether); // 0.4 ether * 1 / (1 + 5)
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(bob), 0.333333333333333330 ether); // (0.4 ether * 5 / (1 + 5)

        // Alice claims her rewards, Bob didn't
        meEthInstance.claimBoostedStakingRewards(alice);
        assertEq(meEthInstance.balanceOf(alice), 5 ether + 0.1 ether + 0.066666666666666666 ether - 1);
        assertEq(meEthInstance.balanceOf(bob), 5 ether + 0.5 ether + 0.333333333333333330 ether);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), 0);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(bob), 0.333333333333333330 ether);

        // 22 eETH -> 24.2 eETH
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(2 ether + 2.2 ether);
        assertEq(eETHInstance.totalSupply(), 24.2 ether);
        vm.stopPrank();

        // Harvest
        // eEth rewards pot size = 0.4 ether + 0.4 ether - Alice's withdrawal amount
        meEthInstance.harvestSacrificedStakingRewards(tier);
        assertEq(meEthInstance.eEthRewardsPotAmountPerTier(tier), 0.4 ether);

        uint256 aliceShare = meEthInstance._shares(alice);
        uint256 bobShare = meEthInstance._shares(bob);
        skip(28 days);
        uint256 aliceBoostedRewards = 0.4 ether * aliceShare / (aliceShare + bobShare);
        uint256 bobBoostedRewards = 0.4 ether * bobShare / (aliceShare + bobShare);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(alice), aliceBoostedRewards);
        assertEq(meEthInstance.getClaimableBoostedStakingRewards(bob), 0.333333333333333330 ether + bobBoostedRewards);

        meEthInstance.claimBoostedStakingRewards(bob);
        assertEq(meEthInstance.balanceOf(alice), 5 ether + 0.1 ether + 0.01 ether + 0.1 ether + 0.066666666666666666 ether + 0.006666666666666666 ether + aliceBoostedRewards);
        assertEq(meEthInstance.balanceOf(bob), 5 ether + 0.5 ether + 0.05 ether + 0.5 ether + 0.333333333333333330 ether + bobBoostedRewards - 1);

        meEthInstance.claimBoostedStakingRewards(alice);
    }

    function test_basic() public {
        vm.deal(alice, 2 ether);

        vm.startPrank(alice);

        // Alice deposits 2 ETH and mints 2 eETH.
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(meEthInstance.balanceOf(alice), 0 ether);

        // Alice mints 2 meETH by wrapping 2 eETH starts earning points
        meEthInstance.wrap(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 2 ether);

        // Alice's points start from 0
        assertEq(meEthInstance.pointOf(alice), 0);

        // Alice's points grow...
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 ether * 1);

        // Alice unwraps 1 meETH to 1eETH
        // which burns Alice's total points
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 2 ether * 1 / 2);

        // Alice keeps earnings points
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 ether * 1 / 2 + 1 ether * 1);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 ether * 1 / 2 + 1 ether * 2);

        // Alice unwraps the whole remaining meETH; 1 meETH to 1eETH
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 0);
        vm.stopPrank();
    }

    function test_basic2() public {
        vm.deal(alice, 2 ether);
        vm.deal(bob, 2 ether);

        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        vm.stopPrank();
        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(eETHInstance.balanceOf(bob), 2 ether);

        vm.startPrank(alice);
        meEthInstance.wrap(2 ether);
        meEthInstance.tradeStakingRewardsForPoints(1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();

        assertEq(meEthInstance.balanceOf(alice), 2 ether);
        assertEq(meEthInstance.balanceOf(bob), 2 ether);

        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 1 ether + (200 * 1 ether) / 100);
        
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(1 ether);
        vm.stopPrank();

        assertEq(meEthInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / 4);
        assertEq(meEthInstance.balanceOf(bob), 2 ether + 1 ether * 2 / 4);

        vm.startPrank(alice);
        meEthInstance.untrade(1 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / 4);
 
        meEthInstance.unwrap(1 ether + 1 ether + 1 ether * 1 / 4);
        assertEq(eETHInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / 4);
        assertEq(meEthInstance.balanceOf(alice), 0 ether);
        assertEq(eETHInstance.balanceOf(bob), 0 ether);
        assertEq(meEthInstance.balanceOf(bob), 2 ether + 1 ether * 2 / 4);
    }

    function test_TierSnapshotTimestamp() public {
        uint256 startTimestmap = block.timestamp;
        for (uint i = 1; i < 4 * 1024; i++) {
            skip(1 hours);
            uint256 diff = meEthInstance.currentTierSnapshotTimestamp() - startTimestmap;
            assertEq(diff / (4 * 7 * 24 * 3600), i / (28 * 24));
        }
    }

}