// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract MembershipManagerTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public shoneeProof;
    bytes32[] public bobProof;
    bytes32[] public ownerProof;
    bytes32[] public emptyProof;

    function setUp() public {
        setUpTests();
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        eETHInstance.approve(address(membershipManagerInstance), 1_000_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        eETHInstance.approve(address(membershipManagerInstance), 1_000_000_000 ether);
        vm.stopPrank();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        shoneeProof = merkle.getProof(whiteListedAddresses, 11);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);
    }

    function test_withdrawalPenalty() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.prank(alice);
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 100 ether}(100 ether, 0, aliceProof);
        vm.prank(bob);
        uint256 bobToken = membershipManagerInstance.wrapEth{value: 100 ether}(100 ether, 0, bobProof);
        // NFT's points start from 0
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 0);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 0);
        assertEq(membershipNftInstance.loyaltyPointsOf(bobToken), 0);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 0);

        // wait a few months and claim new tiers
        skip(100 days);
        vm.prank(alice);
        membershipManagerInstance.claimTier(aliceToken);
        vm.prank(bob);
        membershipManagerInstance.claimTier(bobToken);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 2400);
        assertEq(membershipNftInstance.tierOf(aliceToken), 2);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 2400);
        assertEq(membershipNftInstance.tierOf(bobToken), 2);

        // alice unwraps 1% and should lose 1 tier.
        vm.prank(alice);
        membershipManagerInstance.unwrapForEth(aliceToken, 1 ether);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24 * 1); // booted to start of previous tier == 672
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);

        // Bob attempts to unwrap 80% this is disallowed without burning the NFT
        vm.startPrank(bob);
        vm.expectRevert(MembershipManager.ExceededMaxWithdrawal.selector);
        membershipManagerInstance.unwrapForEth(bobToken, 80 ether);
        vm.expectRevert(MembershipManager.ExceededMaxWithdrawal.selector);
        membershipManagerInstance.unwrapForEth(bobToken, 80 ether);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 2400);
        assertEq(membershipNftInstance.tierOf(bobToken), 2);

        // Bob should be unable to burn a token that doesn't belong to him
        vm.expectRevert(MembershipManager.OnlyTokenOwner.selector);
        membershipManagerInstance.withdrawAndBurnForEth(aliceToken);

        // Bob burns the NFT extracting remaining value
        membershipManagerInstance.withdrawAndBurnForEth(bobToken);
        assertEq(bob.balance, 100 ether);
        assertEq(membershipNftInstance.balanceOf(bob, bobToken), 0);

        vm.stopPrank();

    }


    // Note that 1 ether membership points earns 1 kwei (10 ** 6) points a day
    function test_HowPointsGrow() public {
        vm.deal(alice, 2 ether);

        vm.startPrank(alice);
        // Alice mints an NFT with 2 points by wrapping 2 ETH and starts earning points
        uint256 tokenId = membershipManagerInstance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        assertEq(alice.balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 2 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(membershipNftInstance.valueOf(tokenId), 2 ether);

        // Alice's NFT's points start from 0
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 0);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 0);

        // Alice's NFT's points grow...
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 2 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 24);

        // Alice's NFT unwraps 1 membership points to 1 ETH
        membershipManagerInstance.unwrapForEth(tokenId, 1 ether);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 2 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 0);
        assertEq(membershipNftInstance.valueOf(tokenId), 1 ether);
        assertEq(address(liquidityPoolInstance).balance, 1 ether);
        assertEq(alice.balance, 1 ether);

        // Alice's NFT keeps earnings points with the remaining 1 membership points
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 2 * kwei + 1 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 24 * 1);
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 2 * kwei + 1 * kwei * 2);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 24 * 2);

        // Alice's NFT unwraps all her remaining membership points, burning the NFT
        membershipManagerInstance.withdrawAndBurnForEth(tokenId);
        assertEq(membershipNftInstance.balanceOf(alice, tokenId), 0); 
        assertEq(alice.balance, 2 ether);
        vm.stopPrank();
    }

    function test_MaximumPoints() public {
        // Alice is kinda big! holding 1 Million ETH
        vm.deal(alice, 1_000_000 ether);

        vm.startPrank(alice);
        uint256 tokenId = membershipManagerInstance.wrapEth{value: 1_000_000 ether}(1_000_000 ether, 0, aliceProof);

        // (1 gwei = 10^9)
        // Alice earns 1 gwei points a day
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 1 gwei);

        // Alice earns 1000 gwei points for 1000 days (~= 3 years)
        // Note taht 1000 gwei = 10 ** 12 gwei
        skip(999 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 1000 gwei);

        // However, the points' maximum value is (2^40 - 1) and do not grow further
        // This is practically large enough, I believe
        skip(1000 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), type(uint40).max);

        skip(1000 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), type(uint40).max);

        skip(1000 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), type(uint40).max);

        vm.stopPrank();
    }

    function test_MembershipTier() public {
        vm.deal(alice, 10 ether);

        vm.startPrank(alice);
        // Alice deposits 1 ETH and mints 1 membership points.
        uint256 tokenId = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);

        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 0);
        assertEq(membershipNftInstance.claimableTier(tokenId), 0);

        // For the first membership period, Alice earns {loyalty, tier} points
        // - 1 ether earns 1 kwei loyalty points per day
        // - the tier points grow 24 per day regardless of the deposit size
        skip(27 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 27 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 27 * 24);
        assertEq(membershipNftInstance.claimableTier(tokenId), 0);
        assertEq(membershipNftInstance.tierOf(tokenId), 0);

        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 28 * 24);
        assertEq(membershipNftInstance.claimableTier(tokenId), 1);

        // Alice sees that she can claim her tier 1, which is higher than her current tier 0
        // By calling 'claimTier', Alice's tier gets upgraded to the tier 1
        assertEq(membershipNftInstance.claimableTier(tokenId), 1);
        membershipManagerInstance.claimTier(tokenId);
        assertEq(membershipNftInstance.tierOf(tokenId), 1);

        // Alice unwraps 0.5 membership points (which is 50% of her membership points holdings)
        membershipManagerInstance.unwrapForEth(tokenId, 0.5 ether);

        // Tier gets penalized by unwrapping
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(tokenId), 14 * 24 * 0);
        assertEq(membershipNftInstance.tierOf(tokenId), 0);
    }

    function test_EapMigrationFails() public {
        /// @notice This test uses ETH to test the withdrawal and deposit flow due to the complexity of deploying a local wETH/ERC20 pool for swaps

        // Alice claims her funds after the snapshot has been taken. 
        // She then deposits her ETH into the MembershipManager and has her points allocated to her

        // Alice deposit into EAP
        startHoax(alice);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();

        // PAUSE CONTRACTS AND GET READY FOR SNAPSHOT
        vm.startPrank(owner);
        earlyAdopterPoolInstance.pauseContract();
        vm.stopPrank();

        /// SNAPSHOT FROM PYTHON SCRIPT GETS TAKEN HERE
        // Alice's Points are 103680 

        /// MERKLE TREE GETS GENERATED AND UPDATED
        vm.prank(owner);
        membershipManagerInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);

        // Alice Withdraws
        vm.startPrank(alice);
        earlyAdopterPoolInstance.withdraw();
        vm.stopPrank();

        // Alice Deposits into MembershipManager and receives eETH in return
        bytes32[] memory aliceProof = merkleMigration2.getProof(
            dataForVerification2,
            0
        );

        // Alice confirms eligibility
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);

        vm.expectRevert(MembershipManager.InvalidEAPRollover.selector);
        membershipManagerInstance.wrapEthForEap{value: 0.5 ether}(
            1 ether,
            0,
            1 ether,
            103680,
            aliceProof
        );

        vm.expectRevert(MembershipManager.InvalidEAPRollover.selector);
        membershipManagerInstance.wrapEthForEap{value: 3.0 ether}(
            1 ether,
            2 ether,
            1 ether,
            103680,
            aliceProof
        );

        vm.expectRevert(MembershipManager.InvalidEAPRollover.selector);
        membershipManagerInstance.wrapEthForEap{value: 1 ether}(
            1 ether,
            0,
            1 ether,
            0,
            aliceProof
        );
        vm.stopPrank();
    }

    function test_EapMigrationWorks() public {
        /// @notice This test uses ETH to test the withdrawal and deposit flow due to the complexity of deploying a local wETH/ERC20 pool for swaps

        // Alice claims her funds after the snapshot has been taken. 
        // She then deposits her ETH into the MembershipManager and has her points allocated to her

        // Acotrs deposit into EAP
        startHoax(alice);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();

        skip(8 weeks);

        // PAUSE CONTRACTS AND GET READY FOR SNAPSHOT
        vm.startPrank(owner);
        earlyAdopterPoolInstance.pauseContract();
        vm.stopPrank();

        /// SNAPSHOT FROM PYTHON SCRIPT GETS TAKEN HERE
        // Alice's Points are 103680 

        /// MERKLE TREE GETS GENERATED AND UPDATED
        vm.prank(owner);
        membershipManagerInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);

        // Alice Withdraws
        vm.startPrank(alice);
        earlyAdopterPoolInstance.withdraw();
        vm.stopPrank();

        // Alice Deposits into MembershipManager and receives eETH in return
        bytes32[] memory aliceProof = merkleMigration2.getProof(
            dataForVerification2,
            0
        );
        vm.deal(alice, 100 ether);
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        
        uint256 tokenId = membershipManagerInstance.wrapEthForEap{value: 2 ether}(
            2 ether,
            0,
            1 ether,
            103680,
            aliceProof
        );
        vm.stopPrank();

        assertEq(address(membershipManagerInstance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 2 ether);

        // Check that Alice has received membership points
        assertEq(membershipNftInstance.valueOf(tokenId), 2 ether);
        assertEq(membershipNftInstance.tierOf(tokenId), 2); // Gold
        assertEq(eETHInstance.balanceOf(address(membershipManagerInstance)), 2 ether);
    }


    function test_StakingRewards() public {
        vm.deal(alice, 100 ether);

        vm.startPrank(alice);
        // Alice deposits 0.5 ETH and mints 0.5 membership points.
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 0.5 ether}(0.5 ether, 0, aliceProof);
        assertEq(address(liquidityPoolInstance).balance, 0.5 ether);
        vm.stopPrank();

        // Check the balance
        assertEq(membershipNftInstance.valueOf(aliceToken), 0.5 ether);

        // Rebase; staking rewards 0.5 ETH into LP
        vm.startPrank(owner);
        liquidityPoolInstance.rebase(0.5 ether + 0.5 ether, 0.5 ether);
        membershipManagerInstance.distributeStakingRewards();
        vm.stopPrank();

        // Check the blanace of Alice updated by the rebasing
        assertEq(membershipNftInstance.valueOf(aliceToken), 0.5 ether + 0.5 ether);

        skip(28 days);
        // points earnings are based on the initial deposit; not on the rewards
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * 0.5 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.claimableTier(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(aliceToken), 0);

        membershipManagerInstance.claimTier(aliceToken);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);

        // Bob in
        vm.deal(bob, 2 ether);
        vm.startPrank(bob);
        uint256 bobToken = membershipManagerInstance.wrapEth{value: 2 ether}(2 ether, 0, bobProof);
        vm.stopPrank();

        // Alice belongs to the Tier 1, Bob belongs to the Tier 0
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(bobToken), 0);

        assertEq(address(liquidityPoolInstance).balance, 2.5 ether);

        // More Staking rewards 1 ETH into LP
        vm.startPrank(owner);
        liquidityPoolInstance.rebase(2.5 ether + 0.5 ether + 1 ether, 2.5 ether);
        membershipManagerInstance.distributeStakingRewards();
        vm.stopPrank();

        // Alice belongs to the tier 1 with the weight 2
        // Bob belongs to the tier 0 with the weight 1
        uint256 aliceWeightedRewards = 2 * 1 ether * 1 / uint256(3);
        uint256 bobWeightedRewards = 1 * 1 ether * 2 / uint256(3);
        uint256 sumWeightedRewards = aliceWeightedRewards + bobWeightedRewards;
        uint256 sumRewards = 1 ether;
        uint256 aliceRescaledRewards = aliceWeightedRewards * sumRewards / sumWeightedRewards;
        uint256 bobRescaledRewards = bobWeightedRewards * sumRewards / sumWeightedRewards;
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether + aliceRescaledRewards - 1); // some rounding errors
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether + bobRescaledRewards - 2); // some rounding errors

        // They claim the rewards
        membershipManagerInstance.claimStakingRewards(aliceToken);
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether + aliceRescaledRewards - 1); // some rounding errors
        membershipManagerInstance.claimStakingRewards(bobToken);
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether + bobRescaledRewards - 2); // some rounding errors
    }

    function test_OwnerPermissions() public {
        vm.deal(alice, 1000 ether);
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        membershipManagerInstance.updatePointsGrowthRate(12345);
        vm.expectRevert("Ownable: caller is not the owner");
        membershipManagerInstance.updatePointsBoostFactor(12345);
        vm.stopPrank();

        vm.startPrank(owner);
        membershipManagerInstance.updatePointsGrowthRate(12345);
        membershipManagerInstance.updatePointsBoostFactor(12345);
        vm.stopPrank();
    }


    function test_topUpDilution() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // alice doubles her deposit and should get penalized
        vm.startPrank(alice);

        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        skip(28 days * 10);

        uint256 currentPoints = membershipNftInstance.tierPointsOf(aliceToken);
        assertEq(currentPoints, 6720); // force update if calculation logic changes

        assertEq(membershipNftInstance.claimableTier(aliceToken), 4);
        membershipManagerInstance.claimTier(aliceToken);
        assertEq(membershipNftInstance.tierOf(aliceToken), 4);

        // points should get diluted by 50% & the tier is properly updated
        membershipManagerInstance.topUpDepositWithEth{value: 1 ether}(aliceToken, 1 ether, 0 ether, aliceProof);
        uint256 dilutedPoints = membershipNftInstance.tierPointsOf(aliceToken);
        assertEq(dilutedPoints , currentPoints / 2);
        assertEq(membershipNftInstance.tierOf(aliceToken), 2);
        assertEq(membershipNftInstance.tierOf(aliceToken), membershipManagerInstance.tierForPoints(uint40(dilutedPoints)));

        vm.stopPrank();

        // bob does a 15% top up and should not get penalized
        vm.startPrank(bob);

        uint256 bobToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, bobProof);
        skip(28 days * 10);

        currentPoints = membershipNftInstance.tierPointsOf(bobToken);
        assertEq(currentPoints, 6720); // force update if calculation logic changes

        // points should not get diluted
        membershipManagerInstance.topUpDepositWithEth{value: 0.15 ether}(bobToken, 0.15 ether, 0 ether, bobProof);
        dilutedPoints = membershipNftInstance.tierPointsOf(bobToken);
        assertEq(dilutedPoints , currentPoints); 

        vm.stopPrank();
    }

    function test_topUpDepositWithEth() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.startPrank(alice);
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 8 ether}(8 ether, 0, aliceProof);

        skip(28 days);

        membershipManagerInstance.topUpDepositWithEth{value: 1 ether}(aliceToken, 0.5 ether, 0.5 ether, aliceProof);
        assertEq(membershipNftInstance.valueOf(aliceToken), 8 ether + 1 ether);

        // can't top up again immediately
        vm.expectRevert(MembershipManager.OncePerMonth.selector);
        membershipManagerInstance.topUpDepositWithEth{value: 1 ether}(aliceToken, 0.5 ether, 0.5 ether, aliceProof);

        skip(28 days);

        // deposit is larger so should be able to top up more
        membershipManagerInstance.topUpDepositWithEth{value: 1 ether}(aliceToken, 0.5 ether, 0.5 ether, aliceProof);
        assertEq(membershipNftInstance.valueOf(aliceToken), 9 ether + 1 ether);

        skip(28 days);

        // Alice's NFT has 10 ether in total. 
        // among 10 ether, 1 ether is stake for points (sacrificing the staking rewards)
        uint40 aliceTierPoints = membershipNftInstance.tierPointsOf(aliceToken);
        uint40 aliceLoyaltyPoints = membershipNftInstance.loyaltyPointsOf(aliceToken);
        skip(1 days);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken) - aliceTierPoints, 24 + 24 * uint256(1) / uint256(10));
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken) - aliceLoyaltyPoints, 10 * kwei + 10 * kwei * uint256(1) / uint256(10));
        vm.stopPrank();
    }

    function test_SacrificeRewardsForPoints() public {
        skip(28 days);
        vm.deal(alice, 2 ether);
        vm.deal(bob, 2 ether);

        // Both Alice and Bob mint 2 membership points.

        // - Alice takes weird ways though 
        //   and stakes 1 membership points to earn more points by sacrificing the staking rewards
        vm.startPrank(alice);
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1.8 ether}(1.6 ether, 0.2 ether, aliceProof);
        membershipManagerInstance.stakeForPoints(aliceToken, 0.6 ether);
        membershipManagerInstance.topUpDepositWithEth{value: 0.2 ether}(aliceToken, 0, 0.2 ether, aliceProof);
        vm.stopPrank();

        vm.startPrank(bob);
        uint256 bobToken = membershipManagerInstance.wrapEth{value: 2 ether}(2 ether, 0, bobProof);
        vm.stopPrank();

        // They have the same amounts of membership points and belong to the same tier
        assertEq(membershipNftInstance.valueOf(aliceToken), 2 ether);
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether);
        assertEq(membershipNftInstance.tierOf(aliceToken), membershipNftInstance.tierOf(bobToken));

        // Bob's 2 membership points earns 2 kwei loyalty points AND 24 tier points a day
        // Alice's 2 membership points earns (1 + 1 * 2) kwei loyalty points AND 24 * 1.5 tier points a day
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei + 2 * kwei);
        assertEq(membershipNftInstance.loyaltyPointsOf(bobToken),   2 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 24 + 12);
        assertEq(membershipNftInstance.tierPointsOf(bobToken),  24);

        // Now, eETH is rebased with the staking rewards 1 eETH
        startHoax(owner);
        liquidityPoolInstance.rebase(4 ether + 1 ether, 4 ether);
        membershipManagerInstance.distributeStakingRewards();
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 1 ether}(owner, ownerProof);
        assertEq(address(liquidityPoolInstance).balance, 5 ether);
        vm.stopPrank();

        // Alice's 1 membership points does not earn any rewards
        // Alice's 1 membership points and Bob's 2 membership points earn 1/3 membership points and 2/3 membership points, respectively.
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether + 1 ether + 1 ether * 1 / uint256(3));
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether + (1 ether * 2) / uint256(3));

        // Alice unstakes the 1 membership points which she sacrificed for points
        vm.startPrank(alice);
        membershipManagerInstance.unstakeForPoints(aliceToken, 1 ether);
        vm.stopPrank();
        
        // Alice and Bob burn their tokens and unwrap their whole amounts of membership points to eETH
        vm.startPrank(alice);
        membershipManagerInstance.withdrawAndBurnForEth(aliceToken);
        vm.stopPrank();

        vm.startPrank(bob);
        membershipManagerInstance.withdrawAndBurnForEth(bobToken);
        vm.stopPrank();

        assertEq(alice.balance, 2.333333333333333333 ether);
        assertEq(membershipNftInstance.balanceOf(bob, aliceToken), 0);
        assertEq(bob.balance, 2.666666666666666666 ether);
        assertEq(membershipNftInstance.balanceOf(bob, bobToken), 0);
    }

    function test_unwrapForEth() public {
        vm.deal(alice, 2 ether);
        assertEq(alice.balance, 2 ether);

        vm.startPrank(alice);
        // Alice mints an membership points by wrapping 2 ETH starts earning points
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(membershipNftInstance.valueOf(aliceToken), 2 ether);

        // Alice burns membership points directly for ETH
        membershipManagerInstance.unwrapForEth(aliceToken, 1 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);
        assertEq(alice.balance, 1 ether);

        vm.expectRevert(MembershipManager.InsufficientLiquidity.selector);
        membershipManagerInstance.unwrapForEth(aliceToken, 5 ether);
    }


    /*
    TODO:Re-enable when EEth returns
    function test_LiquidStakingAccessControl() public {
        vm.deal(alice, 2 ether);

        // Alice mints 2 membership points.
        vm.prank(alice);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);

        vm.prank(owner);
        liquidityPoolInstance.closeEEthLiquidStaking();

        vm.prank(alice);
        vm.expectRevert("Liquid staking functions are closed");
        membershipManagerInstance.wrapEEth(2 ether, 0);

        vm.prank(owner);
        liquidityPoolInstance.openEEthLiquidStaking();

        vm.prank(alice);
        uint256 aliceToken = membershipManagerInstance.wrapEEth(2 ether, 0);

        vm.prank(owner);
        liquidityPoolInstance.closeEEthLiquidStaking();

        vm.prank(alice);
        vm.expectRevert("Liquid staking functions are closed");
        membershipManagerInstance.unwrapForEEth(aliceToken, 2 ether);
    }
    */

    function test_wrapEth() public {
        vm.deal(alice, 12 ether);

        vm.startPrank(alice);

        // Alice deposits 10 ETH and mints 10 membership points.
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 10 ether}(10 ether, 0, aliceProof);

        // 10 ETH to the LP
        // 10 eETH to the membership points contract
        // 10 membership points to Alice's NFT
        assertEq(address(liquidityPoolInstance).balance, 10 ether);
        assertEq(address(eETHInstance).balance, 0 ether);
        assertEq(address(membershipManagerInstance).balance, 0 ether);
        assertEq(address(alice).balance, 2 ether);
        
        assertEq(eETHInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(membershipManagerInstance)), 10 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);

        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 1); // alice owns it
        assertEq(membershipNftInstance.valueOf(aliceToken), 10 ether);

        // cannot deposit more than minimum
        vm.expectRevert(MembershipManager.InvalidDeposit.selector);
        membershipManagerInstance.wrapEth{value: 0.01 ether}(0.01 ether, 0, aliceProof);

        // should get entirely new token with a 2nd deposit
        uint256 token2 = membershipManagerInstance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        assert(aliceToken != token2);

        assertEq(address(liquidityPoolInstance).balance, 12 ether);
        assertEq(address(eETHInstance).balance, 0 ether);
        assertEq(address(membershipManagerInstance).balance, 0 ether);
        assertEq(address(alice).balance, 0 ether);
        
        assertEq(eETHInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(membershipManagerInstance)), 12 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);

        assertEq(membershipNftInstance.valueOf(token2), 2 ether);   
    }

    function test_WrapEthFailsIfNotCorrectlyEligible() public {
        //NOTE: Test that wrappingETH fails in both scenarios listed below:
            // 1. User is not whitelisted
            // 2. User is whitelisted but not registered

        //Giving 12 Ether to alice and henry
        vm.deal(henry, 12 ether);
        vm.deal(alice, 12 ether);

        vm.prank(owner);
        stakingManagerInstance.enableWhitelist();

        vm.prank(henry);

        // Henry tries to mint but fails because he is not whitelisted.
        vm.expectRevert("User is not whitelisted");
        uint256 Token = membershipManagerInstance.wrapEth{value: 10 ether}(10 ether, 0, emptyProof);

        //Giving 12 Ether to shonee
        vm.deal(shonee, 12 ether);
        vm.startPrank(shonee);

        //This is the merkle proof for Shonee
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 11);

        // Now shonee cant mint because she is not registered, even though she is whitelisted
        vm.expectRevert("User is not eligible to participate");
        Token = membershipManagerInstance.wrapEth{value: 10 ether}(10 ether, 0, shoneeProof);
    }

    function test_UpdatingPointsGrowthRate() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        // Alice earns 1 kwei per day by holding 1 membership points
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei);

        vm.startPrank(owner);
        // The points growth rate decreased to 5000 from 10000
        membershipManagerInstance.updatePointsGrowthRate(5000);
        vm.stopPrank();

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei / 2);
    }

    // ether.fi multi-sig can manually set the poitns of an NFT
    function test_setPoints() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        // Alice earns 1 kwei per day by holding 1 membership points
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 24);

        // owner manually sets Alice's tier
        vm.startPrank(owner);
        membershipManagerInstance.setPoints(aliceToken, uint40(28 * kwei), uint40(24 * 28));
        vm.stopPrank();

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 24 * 28);

        assertEq(membershipNftInstance.claimableTier(aliceToken), 1);
        membershipManagerInstance.claimTier(aliceToken);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
    }

    function test_lockToken() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);

        // Alice mints 1 NFT
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);

        // fails because token is not locked
        vm.expectRevert(MembershipNFT.RequireTokenLocked.selector);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");

        // lock token for 5 blocks
        membershipNftInstance.lockToken(aliceToken, 5);
        assertEq(membershipNftInstance.tokenLocks(aliceToken), 6);

        // withdraw should fail during lock period
        vm.expectRevert(MembershipManager.RequireTokenUnlocked.selector);
        membershipManagerInstance.unwrapForEth(aliceToken, 0.1 ether);

        // withdraw and burn should fail during lock period
        vm.expectRevert(MembershipManager.RequireTokenUnlocked.selector);
        membershipManagerInstance.withdrawAndBurnForEth(aliceToken);

        // wait a few blocks
        vm.roll(block.number + 6);

        // withdraw should work now
        membershipManagerInstance.unwrapForEth(aliceToken, 0.1 ether);

        // lock again and transfer
        membershipNftInstance.lockToken(aliceToken, 5);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");

        // lock should be reset for the new owner
        assertEq(membershipNftInstance.tokenLocks(aliceToken), 0);

        vm.stopPrank();
    }

    function test_trade() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerInstance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        skip(28 days);
        membershipManagerInstance.claimTier(aliceToken);

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(bob, aliceToken), 0);

        vm.startPrank(alice);
        // fails because token is not locked
        vm.expectRevert(MembershipNFT.RequireTokenLocked.selector);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");

        membershipNftInstance.lockToken(aliceToken, 100);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");

        vm.stopPrank();

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 0);
        assertEq(membershipNftInstance.balanceOf(bob, aliceToken), 1);
    }

    function test_MixedDeposits() public {
        // Alice claims her funds after the snapshot has been taken. 
        // She then deposits her ETH into the MembershipManager and has her points allocated to her
        // Then, she top-ups with ETH and eETH

        // Acotrs deposit into EAP
        startHoax(alice);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();

        skip(28 days);

        /// MERKLE TREE GETS GENERATED AND UPDATED
        vm.startPrank(owner);
        earlyAdopterPoolInstance.pauseContract();
        membershipManagerInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);
        vm.stopPrank();

        vm.deal(alice, 100 ether);
        bytes32[] memory aliceProof = merkleMigration2.getProof(dataForVerification2, 0);

        // Alice Withdraws
        vm.startPrank(alice);
        earlyAdopterPoolInstance.withdraw();

        // Alice Deposits into MembershipManager and receives membership points in return
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        uint256 tokenId = membershipManagerInstance.wrapEthForEap{value: 2 ether}(2 ether, 0, 1 ether, 103680, aliceProof);
        
        assertEq(membershipNftInstance.valueOf(tokenId), 2 ether);
        assertEq(membershipNftInstance.tierOf(tokenId), 2);

        // Top-up with ETH
        membershipManagerInstance.topUpDepositWithEth{value: 0.2 ether}(tokenId, 0.1 ether, 0.1 ether, aliceProof);
        assertEq(membershipNftInstance.valueOf(tokenId), 2.2 ether);

        skip(28 days);

        /*
        TODO: re-enable when EEth is brought back
        // Top-up with EETH
        liquidityPoolInstance.deposit{value: 0.2 ether}(alice, aliceProof);
        membershipManagerInstance.topUpDepositWithEEth(tokenId, 0.1 ether, 0.1 ether);
        assertEq(membershipNftInstance.valueOf(tokenId), 2.4 ether);
        */

        vm.stopPrank();
    }

    function test_FeeWorksCorrectly() public {
        launch_validator(); // there will be 2 validators from the beginning

        vm.startPrank(owner);
        membershipManagerInstance.setFeeAmounts(0.05 ether, 0.05 ether);
        membershipManagerInstance.setFeeSplits(20, 80);
        vm.stopPrank();

        (uint256 mintFee, uint256 burnFee) = membershipManagerInstance.getFees();
        assertEq(mintFee, 0.05 ether);
        assertEq(burnFee, 0.05 ether);
        assertEq(membershipManagerInstance.treasuryFeeSplitPercent(), 20);
        assertEq(membershipManagerInstance.protocolRevenueFeeSplitPercent(), 80);

        vm.prank(alice);
        uint256 tokenId = membershipManagerInstance.wrapEth{value: 2 ether + mintFee}(2 ether, 0, aliceProof);
        (uint256 amount, ) = membershipManagerInstance.tokenDeposits(tokenId);

        assertEq(amount, 2 ether);
        assertEq(address(liquidityPoolInstance).balance, 2 ether);
        assertEq(address(membershipManagerInstance).balance, 0.05 ether); // totalFeesAccumulated
        assertEq(eETHInstance.balanceOf(address(membershipManagerInstance)), 2 ether);
        assertEq(membershipNftInstance.balanceOf(alice, tokenId), 1);

        uint256 aliceBalBefore = alice.balance;
        vm.prank(alice);
        membershipManagerInstance.withdrawAndBurnForEth(tokenId);
        (amount, ) = membershipManagerInstance.tokenDeposits(tokenId);

        assertEq(address(alice).balance, aliceBalBefore + 2 ether - burnFee);
        assertEq(amount, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0 ether);
        assertEq(address(membershipManagerInstance).balance, 0.1 ether); // totalFeesAccumulated
        assertEq(eETHInstance.balanceOf(address(membershipManagerInstance)), 0 ether);
        assertEq(membershipNftInstance.balanceOf(alice, tokenId), 0);

        uint256 treausryBalanceBefore = address(treasuryInstance).balance;
        uint256 prmBalanceBefore = address(protocolRevenueManagerInstance).balance;

        vm.prank(owner);
        membershipManagerInstance.withdrawFees();

        assertEq(address(treasuryInstance).balance, treausryBalanceBefore + 0.02 ether);
        assertEq(address(protocolRevenueManagerInstance).balance, prmBalanceBefore + 0.08 ether);
        assertEq(address(membershipManagerInstance).balance, 0 ether); // totalFeesAccumulated
    }

    function test_SettingFeesFail() public {
        vm.expectRevert("Ownable: caller is not the owner");
        membershipManagerInstance.setFeeAmounts(0.05 ether, 0.05 ether);
        vm.expectRevert("Ownable: caller is not the owner");
        membershipManagerInstance.setFeeSplits(20, 80);
        
        vm.startPrank(owner);

        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeAmounts(0.001 ether * uint256(type(uint16).max) + 1, 0);

        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeAmounts(0, 0.001 ether * uint256(type(uint16).max) + 1);

        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeSplits(10, 80);

        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeSplits(21, 80);

        vm.stopPrank();
    }

    function launch_validator() internal {
        vm.deal(owner, 100 ether);
        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(_ipfsHash, 5);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0);

        hoax(alice);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.2 ether}(2, 0.1 ether);

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 60 ether}(bob, bobProof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);
        vm.stopPrank();

        bytes32[] memory proof = getWhitelistMerkleProof(9);

        vm.prank(owner);
        uint256[] memory newValidators = liquidityPoolInstance.batchDepositWithBidIds{value: 2 * 2 ether}(2, bidIds, proof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](2);

        for (uint256 i = 0; i < newValidators.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                newValidators[i]
            );
            bytes32 root = depGen.generateDepositRoot(
                hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                managerInstance.generateWithdrawalCredentials(etherFiNode),
                32 ether
            );
            depositDataArray[i] = IStakingManager.DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        }

        bytes32 depositRoot = _getDepositRoot();
        vm.prank(owner);
        liquidityPoolInstance.batchRegisterValidators(depositRoot, newValidators, depositDataArray);
    }
}
