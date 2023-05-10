// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract meEthTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    event MEETHBurnt(address indexed _recipient, uint256 _amount);

    function setUp() public {
        setUpTests();
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        eETHInstance.approve(address(meEthInstance), 1_000_000_000 ether);
        vm.stopPrank();

        // TODO: Find a proper way to do this approval
        vm.startPrank(address(meEthInstance));
        eETHInstance.approve(address(meEthInstance), 1_000_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        eETHInstance.approve(address(meEthInstance), 1_000_000_000 ether);
        vm.stopPrank();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
    }

    function test_HowPointsGrow() public {
        // Note that 1 ether meETH earns 1 kwei (10 ** 6) points a day

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
        assertEq(meEthInstance.pointOf(alice), 2 * kwei);

        // Alice unwraps 1 meETH to 1eETH
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 2 * kwei);

        // Alice keeps earnings points with the remaining 1 meETH
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 * kwei + 1 * kwei);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 * kwei + 1 * kwei * 2);

        // Alice unwraps the whole remaining meETH, but the points remain the same
        meEthInstance.unwrap(1 ether);
        assertEq(meEthInstance.pointOf(alice), 2 * kwei + 1 * kwei * 2);
        vm.stopPrank();
    }

    function test_MaximumPoints() public {
        // Alice is kinda big! holding 1 Million ETH
        vm.deal(alice, 1_000_000 ether);

        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 1_000_000 ether}(alice, aliceProof);
        meEthInstance.wrap(1_000_000 ether);

        // (1 gwei = 10^9)
        // Alice earns 1 gwei points a day
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 1 gwei);

        // Alice earns 1000 gwei points for 1000 days (~= 3 years)
        // Note taht 1000 gwei = 10 ** 12 gwei
        skip(999 days);
        assertEq(meEthInstance.pointOf(alice), 1000 gwei);

        // However, the points' maximum value is (2^40 - 1) and do not grow further
        // This is practically large enough, I believe
        skip(1000 days);
        assertEq(meEthInstance.pointOf(alice), type(uint40).max);

        skip(1000 days);
        assertEq(meEthInstance.pointOf(alice), type(uint40).max);

        skip(1000 days);
        assertEq(meEthInstance.pointOf(alice), type(uint40).max);

        vm.stopPrank();
    }

    function test_MembershipTier() public {
        // Membership period = 28 days
        // |--------------|-------------|------------
        // 0            28 days      56 days      ...
        // Here, the starting point '0' indicates the time when the meETH contract is deployed

        vm.deal(alice, 10 ether);

        vm.startPrank(alice);
        // Alice deposits 10 ETH and mints 10 eETH.
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
        assertEq(meEthInstance.pointOf(alice), 27 * kwei);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 0);
        assertEq(meEthInstance.claimableTier(alice), 0);
        assertEq(meEthInstance.tierOf(alice), 0);

        // <Second period begins>
        // Now, after a month (= 28 days), Alice's earned points are eligible for the membership tier
        // Alice's claimable tier is 2 while the current tier is still 0
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 28 * kwei);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 28 * kwei);
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
        assertEq(meEthInstance.pointOf(alice), 28 * kwei);
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
        liquidityPoolInstance.setAccruedStakingRewards(0.5 ether);
        vm.stopPrank();

        // Check the blanace of Alice updated by the rebasing
        assertEq(meEthInstance.balanceOf(alice), 0.5 ether + 0.5 ether);

        skip(28 days);
        // points earnings are based on the initial deposit; not on the rewards
        assertEq(meEthInstance.pointOf(alice), 28 * 0.5 * kwei);
        assertEq(meEthInstance.getPointsEarningsDuringLastMembershipPeriod(alice), 28 * 0.5 * kwei);
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
        liquidityPoolInstance.setAccruedStakingRewards(0.5 ether + 1 ether);
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

        // Both Alice and Bob mint 2 meETH.
        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();

        // Alice stakes 1 meETH to earn more points by sacrificing the staking rewards
        vm.startPrank(alice);
        meEthInstance.stakeForPoints(1 ether);
        vm.stopPrank();

        // They have the same amounts of meETH and belong to the same tier
        assertEq(meEthInstance.balanceOf(alice), 2 ether);
        assertEq(meEthInstance.balanceOf(bob), 2 ether);
        assertEq(meEthInstance.tierOf(alice), meEthInstance.tierOf(bob));

        // Bob's 2 meETH earns 2 kwei points a day
        // Alice's 1 meETH earns 1 kwei points a day
        // Alice's 1 meETH staked for points earns 2 kwei points a day (which is twice larger)
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 1 * kwei + 2 * kwei);
        assertEq(meEthInstance.pointOf(bob),   2 * kwei);
        
        // Now, eETH is rebased with the staking rewards 1 eETH
        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingRewards(1 ether);
        vm.stopPrank();

        // Alice's 1 meETH does not earn any rewards
        // Alice's 1 meETH and Bob's 2 meETH earn 1/3 meETH and 2/3 meETH, respectively.
        assertEq(meEthInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / uint256(3));
        assertEq(meEthInstance.balanceOf(bob), 2 ether + (1 ether * 2) / uint256(3));

        // Alice unstakes the 1 meETH which she staked for points
        vm.startPrank(alice);
        meEthInstance.unstakeForPoints(1 ether);
        vm.stopPrank();

        // Alice and Bob unwrap their whole amounts of meETH to eETH
        vm.startPrank(alice);
        meEthInstance.unwrap(1 ether + 1 ether + 1 ether * 1 / uint256(3));
        vm.stopPrank();

        vm.startPrank(bob);
        meEthInstance.unwrap(2 ether + 1 ether * 2 / uint256(3));
        vm.stopPrank();

        assertEq(eETHInstance.balanceOf(alice), 1 ether + 1 ether + 1 ether * 1 / uint256(3) - 1);
        assertEq(meEthInstance.balanceOf(alice), 0);
        assertEq(eETHInstance.balanceOf(bob), 2 ether + 1 ether * 2 / uint256(3) - 1);
        assertEq(meEthInstance.balanceOf(bob), 0);
    }

    function test_transferFails() public {
        vm.deal(alice, 2 ether);
        vm.deal(bob, 2 ether);

        // Both Alice and Bob mint 2 meETH.
        vm.startPrank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();
        vm.startPrank(bob);
        liquidityPoolInstance.deposit{value: 2 ether}(bob, bobProof);
        meEthInstance.wrap(2 ether);
        vm.stopPrank();

        // Alice sends 1 meETH to Bob, which fails.
        vm.startPrank(alice);
        vm.expectRevert("Transfer of meETH is not allowed");
        meEthInstance.transfer(bob, 1 ether);

        vm.expectRevert("Transfer of meETH is not allowed");
        meEthInstance.transferFrom(alice, bob, 1 ether);
        vm.stopPrank();
    }

    function test_BurnMeETHForETH() public {
        vm.deal(alice, 2 ether);

        vm.startPrank(alice);

        assertEq(alice.balance, 2 ether);
        // Alice deposits 2 ETH and mints 2 eETH.
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        assertEq(meEthInstance.balanceOf(alice), 0 ether);

        // Alice mints 2 meETH by wrapping 2 eETH starts earning points
        meEthInstance.wrap(2 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 2 ether);

        // Alice burns meETH directly for ETH
        vm.expectEmit(true, false, false, true);
        emit MEETHBurnt(alice, 1 ether);
        meEthInstance.burnMeETHForETH(1 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 1 ether);
        assertEq(alice.balance, 1 ether);

        vm.expectRevert("Not enough ETH in the liquidity pool");
        meEthInstance.burnMeETHForETH(5 ether);

        vm.expectRevert("Not enough eETH");
        liquidityPoolInstance.withdraw(alice, 1 ether);
    }

    function test_LiquadStakingAccessControl() public {
        vm.deal(alice, 2 ether);
        vm.deal(bob, 2 ether);

        // Both Alice and Bob mint 2 meETH.
        vm.prank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);

        vm.prank(owner);
        liquidityPoolInstance.closeLiquadStaking();

        vm.prank(alice);
        vm.expectRevert("Liquid staking functions are closed");
        meEthInstance.wrap(2 ether);

        vm.prank(owner);
        liquidityPoolInstance.openLiquadStaking();

        vm.prank(alice);
        meEthInstance.wrap(2 ether);

        vm.prank(owner);
        liquidityPoolInstance.closeLiquadStaking();

        vm.prank(alice);
        vm.expectRevert("Liquid staking functions are closed");
        meEthInstance.unwrap(2 ether);
    }
    function test_wrapEth() public {
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);

        // Alice deposits 10 ETH and mints 10 meETH.
        meEthInstance.wrapEth{value: 10 ether}(alice, aliceProof);

        // 10 ETH to the LP
        // 10 eETH to the meEth contract
        // 10 meETH to Alice
        assertEq(address(liquidityPoolInstance).balance, 10 ether);
        assertEq(address(eETHInstance).balance, 0 ether);
        assertEq(address(meEthInstance).balance, 0 ether);
        assertEq(address(alice).balance, 0 ether);
        
        assertEq(eETHInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(meEthInstance)), 10 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);

        assertEq(meEthInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(meEthInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(meEthInstance.balanceOf(address(meEthInstance)), 0 ether);
        assertEq(meEthInstance.balanceOf(alice), 10 ether);
    
        // Check the points grow properly
        assertEq(meEthInstance.pointOf(alice), 0);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 1 * 10 * kwei);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 2 * 10 * kwei);
        meEthInstance.updatePoints(alice);
        assertEq(meEthInstance.pointOf(alice), 2 * 10 * kwei);
        skip(1 days);
        assertEq(meEthInstance.pointOf(alice), 3 * 10 * kwei);
    }
}