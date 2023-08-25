// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract MembershipManagerTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public danProof;
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
        danProof = merkle.getProof(whiteListedAddresses, 6);
        shoneeProof = merkle.getProof(whiteListedAddresses, 11);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);

        _upgradeMembershipManagerFromV0ToV1();
    }

    function test_withdrawalPenalty() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.prank(alice);
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 100 ether}(100 ether, 0, aliceProof);
        vm.prank(bob);
        uint256 bobToken = membershipManagerV1Instance.wrapEth{value: 100 ether}(100 ether, 0, bobProof);
        // NFT's points start from 0
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 0);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 0);
        assertEq(membershipNftInstance.loyaltyPointsOf(bobToken), 0);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 0);

        // wait a few months and claim new tiers
        skip(100 days);
        vm.prank(alice);
        membershipManagerV1Instance.claim(aliceToken);
        vm.prank(bob);
        membershipManagerV1Instance.claim(bobToken);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 2400);
        assertEq(membershipNftInstance.tierOf(aliceToken), 2);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 2400);
        assertEq(membershipNftInstance.tierOf(bobToken), 2);

        // alice unwraps 1% and should lose 1 tier.
        vm.prank(alice);
        uint256 aliceTokenId = membershipManagerV1Instance.requestWithdraw(aliceToken, 1 ether);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24 * 1); // booted to start of previous tier == 672
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);

        // Bob attempts to unwrap 80% this is disallowed without burning the NFT
        vm.startPrank(bob);
        vm.expectRevert(MembershipManager.ExceededMaxWithdrawal.selector);
        membershipManagerV1Instance.requestWithdraw(bobToken, 80 ether);
        assertEq(membershipNftInstance.tierPointsOf(bobToken), 2400);
        assertEq(membershipNftInstance.tierOf(bobToken), 2);

        // Bob should be unable to burn a token that doesn't belong to him
        vm.expectRevert(MembershipManager.OnlyTokenOwner.selector);
        membershipManagerV1Instance.requestWithdrawAndBurn(aliceToken);

        // Bob burns the NFT extracting remaining value
        uint256 bobTokenId = membershipManagerV1Instance.requestWithdrawAndBurn(bobToken);
        vm.stopPrank();

        vm.prank(alice);
        withdrawRequestNFTInstance.finalizeRequests(bobTokenId);

        vm.prank(bob);
        withdrawRequestNFTInstance.claimWithdraw(bobTokenId);

        assertEq(bob.balance, 100 ether, "Bob should have 100 ether");
        assertEq(membershipNftInstance.balanceOf(bob, bobToken), 0);
    }


    // Note that 1 ether membership points earns 1 kwei (10 ** 6) points a day
    function test_HowPointsGrow() public {
        vm.deal(alice, 2 ether);

        vm.startPrank(alice);
        // Alice mints an NFT with 2 points by wrapping 2 ETH and starts earning points
        uint256 tokenId = membershipManagerV1Instance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
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
        uint256 aliceRequestId1 = membershipManagerV1Instance.requestWithdraw(tokenId, 1 ether);
        withdrawRequestNFTInstance.finalizeRequests(aliceRequestId1);
        withdrawRequestNFTInstance.claimWithdraw(aliceRequestId1);
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
        uint256 aliceRequestId2 = membershipManagerV1Instance.requestWithdrawAndBurn(tokenId);
        withdrawRequestNFTInstance.finalizeRequests(aliceRequestId2);
        withdrawRequestNFTInstance.claimWithdraw(aliceRequestId2);
        assertEq(membershipNftInstance.balanceOf(alice, tokenId), 0); 
        assertEq(alice.balance, 2 ether);
        vm.stopPrank();
    }

    function test_MaximumPoints() public {
        // Alice is kinda big! holding 1 Million ETH
        vm.deal(alice, 1_000_000 ether);

        vm.startPrank(alice);
        uint256 tokenId = membershipManagerV1Instance.wrapEth{value: 1_000_000 ether}(1_000_000 ether, 0, aliceProof);

        // (1 gwei = 10^9)
        // Alice earns 1 gwei points a day
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(tokenId), 1 gwei);

        // Alice earns 1000 gwei points for 1000 days (~= 3 years)
        // Note that 1000 gwei = 10 ** 12 gwei
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
        uint256 tokenId = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);

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
        // By calling 'claim', Alice's tier gets upgraded to the tier 1
        assertEq(membershipNftInstance.claimableTier(tokenId), 1);
        membershipManagerV1Instance.claim(tokenId);
        assertEq(membershipNftInstance.tierOf(tokenId), 1);

        // Alice unwraps 0.5 membership points (which is 50% of her membership points holdings)
        membershipManagerV1Instance.requestWithdraw(tokenId, 0.5 ether);

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
        vm.prank(alice);
        membershipNftInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);

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
        membershipManagerV1Instance.wrapEthForEap{value: 0.5 ether}(
            1 ether,
            0,
            16970393 - 10,
            1 ether,
            103680,
            aliceProof
        );

        vm.expectRevert(MembershipManager.InvalidEAPRollover.selector);
        membershipManagerV1Instance.wrapEthForEap{value: 3.0 ether}(
            1 ether,
            2 ether,
            16970393 - 10,
            1 ether,
            103680,
            aliceProof
        );

        vm.expectRevert(MembershipManager.InvalidEAPRollover.selector);
        membershipManagerV1Instance.wrapEthForEap{value: 1 ether}(
            1 ether,
            0,
            16970393 - 10,
            1 ether,
            0,
            aliceProof
        );
        vm.stopPrank();
    }

    function test_EapMigrationWorks() public {
        vm.warp(1689764603 - 8 weeks);
        vm.roll(17726813 - (8 weeks) / 12);

        /// @notice This test uses ETH to test the withdrawal and deposit flow due to the complexity of deploying a local wETH/ERC20 pool for swaps

        // Alice claims her funds after the snapshot has been taken. 
        // She then deposits her ETH into the MembershipManager and has her points allocated to her

        // Actors deposit into EAP
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
        vm.prank(alice);
        membershipNftInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);

        vm.roll(17664247 + 1 weeks / 12);

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
        
        uint256 tokenId = membershipManagerV1Instance.wrapEthForEap{value: 2 ether}(
            2 ether,
            0,
            16970393 - 10, // 10 blocks before the last gold
            1 ether,
            103680,
            aliceProof
        );
        vm.stopPrank();

        assertEq(address(membershipManagerV1Instance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 2 ether);

        // Check that Alice has received membership points
        assertEq(membershipNftInstance.valueOf(tokenId), 2 ether);
        assertEq(membershipNftInstance.tierOf(tokenId), 2); // Gold
        assertEq(eETHInstance.balanceOf(address(membershipManagerV1Instance)), 2 ether);
    }

    // TODO: Fix it. `Rebase` is not working for V1 vault at the moment
    function _test_StakingRewards() public {
        vm.deal(alice, 100 ether);

        vm.startPrank(alice);
        // Alice deposits 0.5 ETH and mints 0.5 membership points.
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 0.5 ether}(0.5 ether, 0, aliceProof);
        assertEq(address(liquidityPoolInstance).balance, 0.5 ether);
        vm.stopPrank();

        // Check the balance
        assertEq(membershipNftInstance.valueOf(aliceToken), 0.5 ether);

        // Rebase; staking rewards 0.5 ETH into LP
        vm.startPrank(alice);
        membershipManagerV1Instance.rebase(0.5 ether + 0.5 ether, 0.5 ether);
        vm.stopPrank();

        // Check the balance of Alice updated by the rebasing
        assertEq(membershipNftInstance.valueOf(aliceToken), 0.5 ether + 0.5 ether);

        skip(28 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 14 * 1 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.claimableTier(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(aliceToken), 0);

        membershipManagerV1Instance.claim(aliceToken);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);

        // Bob in
        vm.deal(bob, 2 ether);
        vm.startPrank(bob);
        uint256 bobToken = membershipManagerV1Instance.wrapEth{value: 2 ether}(2 ether, 0, bobProof);
        vm.stopPrank();

        // Alice belongs to the Tier 1, Bob belongs to the Tier 0
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(bobToken), 0);

        assertEq(address(liquidityPoolInstance).balance, 2.5 ether);

        // More Staking rewards 1 ETH into LP
        vm.startPrank(alice);
        membershipManagerV1Instance.rebase(2.5 ether + 0.5 ether + 1 ether, 2.5 ether);
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
        assertEq(membershipNftInstance.valueOf(bobToken), 2 ether + bobRescaledRewards - 1); // some rounding errors
    }

    function test_OwnerPermissions() public {
        vm.deal(alice, 1000 ether);
        vm.startPrank(owner);
        vm.expectRevert(MembershipManager.OnlyAdmin.selector);
        membershipManagerV1Instance.updatePointsParams(123, 12345);
        vm.expectRevert(MembershipManager.OnlyAdmin.selector);
        membershipManagerV1Instance.updatePointsParams(123, 12345);
        vm.stopPrank();

        vm.startPrank(alice);
        membershipManagerV1Instance.updatePointsParams(12345, 12345);
        vm.stopPrank();
    }

    function test_topUpDilution() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        // alice doubles her deposit and should get penalized
        vm.startPrank(alice);

        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        skip(28 days * 10);

        uint256 currentPoints = membershipNftInstance.tierPointsOf(aliceToken);
        assertEq(currentPoints, 6720); // force update if calculation logic changes

        assertEq(membershipNftInstance.claimableTier(aliceToken), 4);
        membershipManagerV1Instance.claim(aliceToken);
        assertEq(membershipNftInstance.tierOf(aliceToken), 4);

        // points should get diluted by 25% & the tier is properly updated
        membershipManagerV1Instance.topUpDepositWithEth{value: 3 ether}(aliceToken, 3 ether, 0 ether, aliceProof);
        uint256 dilutedPoints = membershipNftInstance.tierPointsOf(aliceToken);
        assertEq(dilutedPoints , currentPoints / 4);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(aliceToken), membershipManagerV1Instance.tierForPoints(uint40(dilutedPoints)));

        vm.stopPrank();

        // bob does a 15% top up and should not get penalized
        vm.startPrank(bob);

        uint256 bobToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, bobProof);
        skip(28 days * 10);

        currentPoints = membershipNftInstance.tierPointsOf(bobToken);
        assertEq(currentPoints, 6720); // force update if calculation logic changes

        // points should not get diluted
        membershipManagerV1Instance.topUpDepositWithEth{value: 0.15 ether}(bobToken, 0.15 ether, 0 ether, bobProof);
        dilutedPoints = membershipNftInstance.tierPointsOf(bobToken);
        assertEq(dilutedPoints , currentPoints); 

        vm.stopPrank();
    }

    function test_topUpDepositWithEth() public {
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.startPrank(alice);
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 8 ether}(8 ether, 0, aliceProof);

        skip(28 days);

        membershipManagerV1Instance.topUpDepositWithEth{value: 1 ether}(aliceToken, 1 ether, 0, aliceProof);
        assertEq(membershipNftInstance.valueOf(aliceToken), 8 ether + 1 ether);

        // can't top up again immediately
        vm.expectRevert(MembershipManager.InvalidDeposit.selector);
        membershipManagerV1Instance.topUpDepositWithEth{value: 1 ether}(aliceToken, 1 ether, 0 ether, aliceProof);

        skip(28 days);

        // deposit is larger so should be able to top up more
        membershipManagerV1Instance.topUpDepositWithEth{value: 1 ether}(aliceToken, 1 ether, 0 ether, aliceProof);
        assertEq(membershipNftInstance.valueOf(aliceToken), 9 ether + 1 ether);

        skip(28 days);

        // Alice's NFT has 10 ether in total. 
        // among 10 ether, 1 ether is stake for points (sacrificing the staking rewards)
        uint40 aliceTierPoints = membershipNftInstance.tierPointsOf(aliceToken);
        uint40 aliceLoyaltyPoints = membershipNftInstance.loyaltyPointsOf(aliceToken);
        skip(1 days);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken) - aliceTierPoints, 24);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken) - aliceLoyaltyPoints, 10 * kwei);
        vm.stopPrank();
    }

    function test_requestWithdraw() public {
        vm.deal(alice, 2 ether);
        assertEq(alice.balance, 2 ether);

        vm.startPrank(alice);
        // Alice mints an membership points by wrapping 2 ETH starts earning points
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(membershipNftInstance.valueOf(aliceToken), 2 ether);

        // Alice burns membership points directly for ETH
        uint256 requestId = membershipManagerV1Instance.requestWithdraw(aliceToken, 1 ether);
        withdrawRequestNFTInstance.finalizeRequests(requestId);
        withdrawRequestNFTInstance.claimWithdraw(requestId);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);
        assertEq(membershipNftInstance.valueOf(aliceToken), 1 ether);
        assertEq(alice.balance, 1 ether);

        vm.expectRevert(MembershipManager.ExceededMaxWithdrawal.selector);
        membershipManagerV1Instance.requestWithdraw(aliceToken, 5 ether);
    }

    function test_wrapEth() public {
        vm.deal(alice, 12 ether);

        vm.startPrank(alice);

        // Alice deposits 10 ETH and mints 10 membership points.
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 10 ether}(10 ether, 0, aliceProof);

        // 10 ETH to the LP
        // 10 eETH to the membership points contract
        // 10 membership points to Alice's NFT
        assertEq(address(liquidityPoolInstance).balance, 10 ether);
        assertEq(address(eETHInstance).balance, 0 ether);
        assertEq(address(membershipManagerV1Instance).balance, 0 ether);
        assertEq(address(alice).balance, 2 ether);
        
        assertEq(eETHInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(membershipManagerV1Instance)), 10 ether);
        assertEq(eETHInstance.balanceOf(alice), 0 ether);

        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 1); // alice owns it
        assertEq(membershipNftInstance.valueOf(aliceToken), 10 ether);

        // cannot deposit more than minimum
        vm.expectRevert(MembershipManager.InvalidDeposit.selector);
        membershipManagerV1Instance.wrapEth{value: 0.01 ether}(0.01 ether, 0, aliceProof);

        // should get entirely new token with a 2nd deposit
        uint256 token2 = membershipManagerV1Instance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        assert(aliceToken != token2);

        assertEq(address(liquidityPoolInstance).balance, 12 ether);
        assertEq(address(eETHInstance).balance, 0 ether);
        assertEq(address(membershipManagerV1Instance).balance, 0 ether);
        assertEq(address(alice).balance, 0 ether);
        
        assertEq(eETHInstance.balanceOf(address(liquidityPoolInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(eETHInstance)), 0 ether);
        assertEq(eETHInstance.balanceOf(address(membershipManagerV1Instance)), 12 ether);
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

        vm.prank(alice);
        stakingManagerInstance.enableWhitelist();

        vm.prank(henry);

        // Henry tries to mint but fails because he is not whitelisted.
        vm.expectRevert("User is not whitelisted");
        uint256 Token = membershipManagerV1Instance.wrapEth{value: 10 ether}(10 ether, 0, emptyProof);

        //Giving 12 Ether to shonee
        vm.deal(shonee, 12 ether);
        vm.startPrank(shonee);

        //This is the merkle proof for Shonee
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 11);

        // Now shonee cant mint because she is not registered, even though she is whitelisted
        vm.expectRevert("User is not eligible to participate");
        Token = membershipManagerV1Instance.wrapEth{value: 10 ether}(10 ether, 0, shoneeProof);
    }

    function test_UpdatingPointsGrowthRate() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        // Alice earns 1 kwei per day by holding 1 membership points
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei);

        vm.startPrank(alice);
        // The points growth rate decreased to 5000 from 10000
        membershipManagerV1Instance.updatePointsParams(10000, 5000);
        vm.stopPrank();

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei / 2);
    }

    // ether.fi multi-sig can manually set the points of an NFT
    function test_setPoints() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        vm.startPrank(alice);
        membershipManagerV1Instance.rebase(address(liquidityPoolInstance).balance * 2, address(liquidityPoolInstance).balance);
        vm.stopPrank();

        // Alice earns 1 kwei per day by holding 1 membership points
        skip(1 days);
        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 1 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 24);
        assertEq(membershipNftInstance.valueOf(aliceToken), 2 * 1 ether);

        // owner manually sets Alice's tier
        vm.prank(alice);
        membershipManagerV1Instance.setPoints(aliceToken, uint40(28 * kwei), uint40(24 * 28));

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 24 * 28);
        assertEq(membershipNftInstance.claimableTier(aliceToken), 1);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.valueOf(aliceToken), 2 * 1 ether);
    }

    function test_lockToken() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);

        // Alice mints 1 NFT
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);

        // make a small withdrawal
        membershipManagerV1Instance.requestWithdraw(aliceToken, 0.1 ether);
        assertEq(membershipNftInstance.transferLockedUntil(aliceToken), block.number + membershipManagerV1Instance.withdrawalLockBlocks());

        // fails because token is locked
        vm.expectRevert(MembershipNFT.RequireTokenUnlocked.selector);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");

        // wait for lock to expire
        vm.roll(block.number + membershipManagerV1Instance.withdrawalLockBlocks());

        // withdraw should succeed
        membershipManagerV1Instance.requestWithdraw(aliceToken, 0.1 ether);

        // withdraw and burn should succeed
        membershipManagerV1Instance.requestWithdrawAndBurn(aliceToken);

        vm.stopPrank();

        // attempt to lock blocks
        vm.prank(bob);
        vm.expectRevert(MembershipManager.OnlyAdmin.selector);
        membershipManagerV1Instance.setWithdrawalLockBlocks(10);

        // alice is the admin?
        vm.prank(alice);
        membershipManagerV1Instance.setWithdrawalLockBlocks(10);
        assertEq(membershipManagerV1Instance.withdrawalLockBlocks(), 10);
    }

    function test_trade() public {
        vm.deal(alice, 1 ether);

        vm.startPrank(alice);
        // Alice mints 1 membership points by wrapping 1 ETH starts earning points
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
        vm.stopPrank();

        skip(28 days);
        membershipManagerV1Instance.claim(aliceToken);

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(bob, aliceToken), 0);

        vm.startPrank(alice);
        membershipNftInstance.safeTransferFrom(alice, bob, aliceToken, 1, "");
        vm.stopPrank();

        assertEq(membershipNftInstance.loyaltyPointsOf(aliceToken), 28 * kwei);
        assertEq(membershipNftInstance.tierPointsOf(aliceToken), 28 * 24);
        assertEq(membershipNftInstance.tierOf(aliceToken), 1);
        assertEq(membershipNftInstance.balanceOf(alice, aliceToken), 0);
        assertEq(membershipNftInstance.balanceOf(bob, aliceToken), 1);
    }

    function test_MixedDeposits() public {
        vm.warp(1689764603 - 8 weeks);
        vm.roll(17726813 - (8 weeks) / 12);

        // Alice claims her funds after the snapshot has been taken. 
        // She then deposits her ETH into the MembershipManager and has her points allocated to her
        // Then, she top-ups with ETH and eETH

        // Actors deposit into EAP
        startHoax(alice);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();

        skip(28 days);

        /// MERKLE TREE GETS GENERATED AND UPDATED
        vm.prank(owner);
        earlyAdopterPoolInstance.pauseContract();
        vm.prank(alice);
        membershipNftInstance.setUpForEap(rootMigration2, requiredEapPointsPerEapDeposit);

        vm.deal(alice, 100 ether);
        bytes32[] memory aliceProof = merkleMigration2.getProof(dataForVerification2, 0);

        vm.roll(17664247 + 1 weeks / 12);

        // Alice Withdraws
        vm.startPrank(alice);
        earlyAdopterPoolInstance.withdraw();

        // Alice Deposits into MembershipManager and receives membership points in return
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        uint256 tokenId = membershipManagerV1Instance.wrapEthForEap{value: 2 ether}(2 ether, 0, 16970393 - 10, 1 ether, 103680, aliceProof);
        
        assertEq(membershipNftInstance.valueOf(tokenId), 2 ether);
        assertEq(membershipNftInstance.tierOf(tokenId), 2); // Gold

        // Top-up with ETH
        membershipManagerV1Instance.topUpDepositWithEth{value: 0.2 ether}(tokenId, 0.2 ether, 0 ether, aliceProof);
        assertEq(membershipNftInstance.valueOf(tokenId), 2.2 ether);

        skip(28 days);

        /*
        TODO: re-enable when EEth is brought back
        // Top-up with EETH
        liquidityPoolInstance.deposit{value: 0.2 ether}(alice, aliceProof);
        membershipManagerV1Instance.topUpDepositWithEEth(tokenId, 0.1 ether, 0.1 ether);
        assertEq(membershipNftInstance.valueOf(tokenId), 2.4 ether);
        */

        vm.stopPrank();
    }

    function test_upgradeFee() public {
        vm.deal(alice, 100 ether);

        // setup fees
        vm.startPrank(alice);
        membershipManagerV1Instance.setFeeAmounts(0 ether, 0 ether, 0.5 ether);

        (uint256 mintFee, uint256 burnFee, uint256 upgradeFee) = membershipManagerV1Instance.getFees();
        assertEq(mintFee, 0 ether);
        assertEq(burnFee, 0 ether);
        assertEq(upgradeFee, 0.5 ether);
        vm.stopPrank();

        vm.startPrank(alice);

        // mint
        uint256 aliceToken = membershipManagerV1Instance.wrapEth{value: 2 ether}(2 ether, 0, aliceProof);
        skip(30 days);

        // attempt to top up without paying fee
        vm.expectRevert();
        membershipManagerV1Instance.topUpDepositWithEth{value: 0.1 ether}(aliceToken, 0.1 ether, 0, aliceProof);

        // attempt to provide in improper amount
        vm.expectRevert(MembershipManager.InvalidDeposit.selector);
        membershipManagerV1Instance.topUpDepositWithEth{value: 5 ether}(aliceToken, 0.1 ether, 0, aliceProof);

        // proper upgrade
        membershipManagerV1Instance.topUpDepositWithEth{value: 0.6 ether}(aliceToken, 0.1 ether, 0, aliceProof);

        // assert that token balance increased by expected value and that contract received the mint fee
        uint256 depositAmount = membershipNftInstance.valueOf(aliceToken);
        assertEq(depositAmount, 2.1 ether);
        assertEq(address(membershipManagerV1Instance).balance, 0.5 ether);

        vm.stopPrank();
    }

    function test_SettingFeesFail() public {
        vm.startPrank(owner);
        vm.expectRevert(MembershipManager.OnlyAdmin.selector);
        membershipManagerInstance.setFeeAmounts(0.05 ether, 0.05 ether, 0 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeAmounts(0.001 ether * uint256(type(uint16).max) + 1, 0, 0 ether);

        vm.expectRevert(MembershipManager.InvalidAmount.selector);
        membershipManagerInstance.setFeeAmounts(0, 0.001 ether * uint256(type(uint16).max) + 1, 0 ether);

        vm.stopPrank();
    }

    function test_update_tier() public {
        vm.startPrank(alice);
        membershipManagerV1Instance.updateTier(0, 0, 10);
        membershipManagerV1Instance.updateTier(1, 1, 15);
        membershipManagerV1Instance.updateTier(2, 2, 20);
        membershipManagerV1Instance.updateTier(3, 3, 25);
        membershipManagerV1Instance.updateTier(4, 4, 30);
        vm.stopPrank();

        vm.deal(alice, 5 ether);
        uint256[] memory tokens = new uint256[](5);
        vm.startPrank(alice);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i] = membershipManagerV1Instance.wrapEth{value: 1 ether}(1 ether, 0, aliceProof);
            membershipManagerV1Instance.setPoints(tokens[i], 0, uint40(i));
            assertEq(membershipNftInstance.tierOf(tokens[i]), uint40(i));
        }
        vm.stopPrank();

        vm.startPrank(alice);
        membershipManagerV1Instance.rebase(5 ether + 1 ether, 5 ether);
        vm.stopPrank();

        assertEq(membershipNftInstance.valueOf(tokens[0]), 1 ether + 1 ether * uint256(10) / uint256(100) - 1);
        assertEq(membershipNftInstance.valueOf(tokens[1]), 1 ether + 1 ether * uint256(15) / uint256(100) - 1);
        assertEq(membershipNftInstance.valueOf(tokens[2]), 1 ether + 1 ether * uint256(20) / uint256(100) );
        assertEq(membershipNftInstance.valueOf(tokens[3]), 1 ether + 1 ether * uint256(25) / uint256(100) - 1);
        assertEq(membershipNftInstance.valueOf(tokens[4]), 1 ether + 1 ether * uint256(30) / uint256(100) - 1);
    }
}
