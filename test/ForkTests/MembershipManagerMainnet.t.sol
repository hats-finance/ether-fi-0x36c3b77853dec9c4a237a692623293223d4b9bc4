// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "./MainnetTestSetup.sol";

// contract MembershipManagerMainnetTest is MainnetTestSetup {

//     bytes32[] public aliceProof;
//     bytes32[] public bobProof;

//     //Fork ID
//     uint256 mainnetFork;

//     //Fork URL
//     string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

//     function setUp() public {

//         //Creating the fork
//         mainnetFork = vm.createFork(MAINNET_RPC_URL);

//         //Selecting the fork
//         vm.selectFork(mainnetFork);

//         //Must come after your create and select the fork
//         setUpTests();
//     }

//     function test_MembershipManagerContractInstantiatedCorrectlyOnMainnet() public {
//         assertEq(
//             membershipManagerInstance.admin(),
//             0x2aCA71020De61bb532008049e1Bd41E451aE8AdC
//         );
//         assertEq(
//             membershipManagerInstance.numberOfTiers(),
//             4
//         );
//         console.log(membershipManagerInstance.sharesReservedForRewards());
//     }

//     //Using a random users data before they rolled
//     function test_EapRoll() public {
//         vm.startPrank(0x256DC7A9CDDAc88c9C80AF0445eCEa056d2298dD);

//         //Moving to a specific block
//         vm.rollFork(17666762);

//         //Fetching current data
//         console.log(membershipNFTInstance.nextMintTokenId());

//         //uint256 tokenId = membershipManagerInstance.wrapEthForEap{value: 0.1 ether}(100000000000000000, 0, 16979693, 100000000000000000, 52758, proof);
//         console.log(membershipNFTInstance.nextMintTokenId());

//         //(, uint40 baseLoyaltyPoints,,,,,) = membershipManagerInstance.tokenData(tokenId);
//         //assertEq(baseLoyaltyPoints, 16979693);
//     }

//     function test_Rebase() public {

//         //Using alice and giving her ETH
//         vm.deal(alice, 100 ether);
//         uint256 LPBalanceBeforeAliceDeposit = address(liquidityPoolInstance).balance;
//         uint256 regulationsManagerBalanceBeforeAliceDeposit = address(membershipManagerInstance).balance;
//         console.log("Liquidity Pool Balance before Alice's deposit: ", LPBalanceBeforeAliceDeposit);
//         console.log("Regulations Manager Balance before Alice's deposit: ", regulationsManagerBalanceBeforeAliceDeposit);
//         console.log("Next token ID: ", membershipNFTInstance.nextMintTokenId());

//         vm.startPrank(alice);
//         regulationsManagerInstance.confirmEligibility(0x0ab8550a37ce88b186c3e9887c7c9914b413f7330155bf4086c8035847c6c6b4);

//         // Alice deposits 5 ETH
//         // Remember to add the fee to the transaction
//         uint256 aliceToken = membershipManagerInstance.wrapEth{value: 5.05 ether}(5 ether, 0, aliceProof);
        
//         uint256 LPBalanceAfterAliceDeposit = address(liquidityPoolInstance).balance;
//         console.log("Liquidity Pool Balance after Alice's deposit: ", LPBalanceAfterAliceDeposit);
//         console.log("Regulations Manager Balance after Alice's deposit: ", address(membershipManagerInstance).balance);
//         console.log("Next token ID: ", membershipNFTInstance.nextMintTokenId());

//         assertEq(LPBalanceAfterAliceDeposit, LPBalanceBeforeAliceDeposit + 5 ether);
//         assertEq(address(membershipManagerInstance).balance, regulationsManagerBalanceBeforeAliceDeposit + 0.05 ether);
//         vm.stopPrank();

//         // Check the balance
//         assertEq(membershipNFTInstance.valueOf(aliceToken), 5 ether);

//         // Rebase; staking rewards 0.5 ETH into LP
//         vm.startPrank(membershipManagerInstance.admin());
//         vm.deal(membershipManagerInstance.admin(), 50000 ether);
//         membershipManagerInstance.rebase(LPBalanceAfterAliceDeposit + 10000 ether, LPBalanceAfterAliceDeposit);
//         console.log("Alice tokens value is now: ", membershipNFTInstance.valueOf(aliceToken));
//         // Check the balance of Alice updated by the rebasing
//         //assertEq(membershipNFTInstance.valueOf(aliceToken), 0.5 ether + 0.5 ether);

//         skip(61 days);
//         // points earnings are based on the initial deposit; not on the rewards
//         assertEq(membershipNFTInstance.loyaltyPointsOf(aliceToken), 61 * 5 * kwei);
//         assertEq(membershipNFTInstance.tierPointsOf(aliceToken), 61 * 24);
//         assertEq(membershipNFTInstance.claimableTier(aliceToken), 1);
//         assertEq(membershipNFTInstance.tierOf(aliceToken), 0);

//         membershipManagerInstance.claim(aliceToken);
//         assertEq(membershipNFTInstance.tierOf(aliceToken), 1);

//         // Bob in
//         vm.deal(bob, 200 ether);
//         vm.startPrank(bob);
//         regulationsManagerInstance.confirmEligibility(0x0ab8550a37ce88b186c3e9887c7c9914b413f7330155bf4086c8035847c6c6b4);
//         uint256 bobToken = membershipManagerInstance.wrapEth{value: 30.05 ether}(30 ether, 0, bobProof);
//         vm.stopPrank();

//         // Check the balance
//         assertEq(membershipNFTInstance.valueOf(bobToken), 30 ether);

//         // Alice belongs to the Tier 1, Bob belongs to the Tier 0
//         assertEq(membershipNFTInstance.valueOf(bobToken), 30 ether);
//         assertEq(membershipNFTInstance.tierOf(aliceToken), 1);
//         assertEq(membershipNFTInstance.tierOf(bobToken), 0);

//         uint256 LPBalanceAfterBobDeposit = address(liquidityPoolInstance).balance;

//         console.log("Liquidity Pool Balance after Bob's deposit: ", LPBalanceAfterBobDeposit);
//         console.log("Regulations Manager Balance after Bob's deposit: ", address(membershipManagerInstance).balance);
//         console.log("Next token ID: ", membershipNFTInstance.nextMintTokenId());

//         // More Staking rewards 1 ETH into LP
//         vm.startPrank(membershipManagerInstance.admin());
//         membershipManagerInstance.rebase(LPBalanceAfterBobDeposit + 10000 ether + 1000 ether, LPBalanceAfterBobDeposit);
//         vm.stopPrank();

//         console.log("Alice tokens value is now: ", membershipNFTInstance.valueOf(aliceToken));
//         console.log("Bob tokens value is now: ", membershipNFTInstance.valueOf(bobToken));

//     }
// }
