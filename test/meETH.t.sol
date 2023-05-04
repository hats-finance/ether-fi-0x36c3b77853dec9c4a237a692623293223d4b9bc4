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
        for (uint256 i = 0; i < 5 ; i++) {
            uint40 minimumPointsRequirement = uint40(i * 14 * 1 * (10 ** 3));
            uint24 weight = uint24(i + 1);
            meEthInstance.addNewTier(minimumPointsRequirement, weight);
        }
        vm.stopPrank();
    }

    function test_HowPointsGrow() public {
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
        assertEq(meEthInstance.pointOf(alice), 2 * (10 ** 3) * 1);

        // Alice unwraps 1 meETH to 1eETH
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 2 * (10 ** 3) * 1);

        // Alice keeps earnings points with the remaining 1 meETH
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 * (10 ** 3) * 1 + 1 * (10 ** 3) * 1);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 * (10 ** 3) * 1 + 1 * (10 ** 3) * 2);

        // Alice unwraps the whole remaining meETH, but the points remain teh same
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 2 * (10 ** 3) * 1 + 1 * (10 ** 3) * 2);
        vm.stopPrank();
    }

    function test_MembershipTier() public {
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);
        // Alice deposits 10 ETH and mints 1 eETH.
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);

        // Alice wraps 1 eETH to 1 meEth
        meEthInstance.wrap(1 ether);

        assertEq(meEthInstance.pointOf(alice), 0);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 0);
        assertEq(meEthInstance.claimableTier(alice), 0);

        // For the first membership period, Alice earns points
        // But, the earned points are not eligible for the membership tier during that period
        // Those points will become eligible to claim the tier during the next period
        skip(27 days);
        assertEq(meEthInstance.pointOf(alice), 27 * 1 * (10 ** 3));
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 0);
        assertEq(meEthInstance.claimableTier(alice), 0);
        assertEq(meEthInstance.tierOf(alice), 0);

        // Now, after a month (= 28 days), Alice's earned points are eligible for the membership tier
        // Alice's claimable tier is 2 while the current tier is still 0
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 28 * 1 * (10 ** 3));
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 28 * 1 * (10 ** 3));
        assertEq(meEthInstance.claimableTier(alice), 2);
        assertEq(meEthInstance.tierOf(alice), 0);

        // Alice sees that she can claim her tier 2, which is higher than her current tier 0
        // By calling 'updateTier', Alice's tier gets upgraded to the tier 2
        assertEq(meEthInstance.claimableTier(alice), 2);
        meEthInstance.updateTier(alice);
        assertEq(meEthInstance.tierOf(alice), 2);

        // Alice unwraps 0.5 meETH (which is 50% of her meETH holdings)
        meEthInstance.unwrap(0.5 ether);

        // The points didn't get penalized by unwrapping
        // But the tier get downgraded from Tier 2 to Tier 1
        assertEq(meEthInstance.pointOf(alice), 28 * 1 * (10 ** 3));
        assertEq(meEthInstance.tierOf(alice), 1);
    }

    function test_StakingRewards() public {
        vm.deal(alice, 0.5 ether);

        vm.startPrank(alice);
        // Alice deposits 0.5 ETH and mints 0.5 eETH.
        liquidityPoolInstance.deposit{value: 0.5 ether}(alice, aliceProof);

        // Alice mints 1 meETH by wrapping 0.5 eETH starts earning points
        meEthInstance.wrap(0.5 ether);
        vm.stopPrank();

        // Check the balance
        assertEq(meEthInstance.balanceOf(alice), 0.5 ether);

        // Rebase; staking rewards 0.5 ETH into LP
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(0.5 ether);
        vm.stopPrank();

        // Check the blanace of Alice updated by the rebasing
        assertEq(meEthInstance.balanceOf(alice), 0.5 ether + 0.5 ether);

        skip(28 days);
        // points earnings are based on the initial deposit; not on the rewards
        assertEq(meEthInstance.pointOf(alice), 28 * 0.5 * (10 ** 3));
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 28 * 0.5 * (10 ** 3));
        assertEq(meEthInstance.claimableTier(alice), 1);
        assertEq(meEthInstance.tierOf(alice), 0);

        meEthInstance.updateTier(alice);
        assertEq(meEthInstance.tierOf(alice), 1);
        assertEq(meEthInstance.balanceOf(alice), 1 ether);

        // Bob in
        vm.deal(bob, 2 ether);
        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();

        // Alice belongs to the Tier 1, Bob belongs to the Tier 0
        assertEq(meEthInstance.balanceOf(alice), 1 ether);
        assertEq(meEthInstance.balanceOf(bob), 2 ether);
        assertEq(meEthInstance.tierOf(alice), 1);
        assertEq(meEthInstance.tierOf(bob), 0);

        // More Staking rewards 1 ETH into LP
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(0.5 ether + 1 ether);
        vm.stopPrank();

        // Alice belongs to the tier 1 with the weight 2
        // Bob belongs to the tier 0 with the weight 1
        uint256 aliceWeightedRewards = 2 * 1 ether * 1 / uint256(3);
        uint256 bobWeightedRewards = 1 * 1 ether * 2 / uint256(3);
        uint256 sumWeightedRewards = aliceWeightedRewards + bobWeightedRewards;
        uint256 sumRewards = 1 ether;
        uint256 aliceRescaledRewards = aliceWeightedRewards * sumRewards / sumWeightedRewards;
        uint256 bobRescaledRewards = bobWeightedRewards * sumRewards / sumWeightedRewards;
        assertEq(meEthInstance.balanceOf(alice), 1 ether + aliceRescaledRewards - 1); // some rounding errors
        assertEq(meEthInstance.balanceOf(bob), 2 ether + bobRescaledRewards - 2); // some rounding errors
    }

    function test_SacrificeRewardsForPoints() public {
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
        meEthInstance.sacrificeRewardsForPoints(1 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();

        assertEq(meEthInstance.balanceOf(alice), 2 ether);
        assertEq(meEthInstance.balanceOf(bob), 2 ether);
        assertEq(meEthInstance.tierOf(alice), meEthInstance.tierOf(bob));

        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 1 * (10 ** 3) + (200 * 1 * (10 ** 3)) / 100);
        
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingReards(1 ether);
        vm.stopPrank();

        assertEq(meEthInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / uint256(3));
        assertEq(meEthInstance.balanceOf(bob), 2 ether + 1 ether * 2 / uint256(3));
        
        vm.startPrank(alice);
        meEthInstance.untrade(1 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / uint256(3));

        meEthInstance.unwrap(1 ether + 1 ether + 1 ether * 1 / uint256(3));
        vm.stopPrank();

        vm.startPrank(bob);
        meEthInstance.claimStakingRewards(bob);
        meEthInstance.unwrap(2 ether + 1 ether * 2 / uint256(3));
        vm.stopPrank();

        assertEq(eETHInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / uint256(3) - 1);
        assertEq(meEthInstance.balanceOf(alice), 0);
        assertEq(eETHInstance.balanceOf(bob), 2 ether + 1 ether * 2 / uint256(3) - 1);
        assertEq(meEthInstance.balanceOf(bob), 0);
    }

}