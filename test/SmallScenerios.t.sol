// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract SmallScenariosTest is TestSetup {
    uint256[] public slippageArray;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public chadProof;
    bytes32[] public ownerProof;

    function setUp() public {
        setUpTests();

        slippageArray = new uint256[](4);
        slippageArray[0] = 90;
        slippageArray[1] = 90;
        slippageArray[2] = 90;
        slippageArray[3] = 90;

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        chadProof = merkle.getProof(whiteListedAddresses, 5);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);
    }
    
    /*
    Alice, Bob and Chad all deposit into the liquidity pool.
    Alice keeps her eETH to earn rebasing rewards.
    Bob wraps his eETH into weETH to use in other DeFi applications.
    Once Rewards are distrubuted, Bob decides to unwrap his weETH back to eETH.
    Bob withdraws his ETH from the pool.
    Chad deposits 16 ETH
    There's more the 32 eth in the pool so EtherFi rolls it up into a validator.
    Chad then wants to withdraw his 16 ETH but there is < Chad's balance in the pool.
    EtherFi deposits their own ETH to keep the pool solvent and allow withdrawals.
    EtherFi requests an exit for the TNFT that was minted.
    Once the nodes exit is observed, EtherFi processes the node's exit from the EtherFiNodesManager
    Rewards are distributed
    Alice's balance rebases from the rewards sent to the TNFT holder, which is the liquidity pool
    
    */ 
    function test_EEthWeTHLpScenarios() public {
        // bids for later rollup
        bobProof = merkle.getProof(whiteListedAddresses, 4);

        startHoax(bob);
        nodeOperatorManagerInstance.registerNodeOperator(bobProof, _ipfsHash, 40);
        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(5, 0.2 ether);
        vm.stopPrank();

        //-------------------------------------------------------------------------------------------------------------------------------
        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0 ether);

        /// Alice confirms she is not a US or Canadian citizen and deposits 10 ETH into the pool.
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        /// Alice is the first depositer so she gets 100% of shares
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        /// Alice total claimable Ether is 10 ETH because she gets 100% of the rewards as she is the only LP.
        /// (10 * 10) / 10
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 10 ether);

        /// Bob then comes along, confirms his elegibility and deposits 5 ETH into the pool.
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 5 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 15 ether);
        assertEq(eETHInstance.totalSupply(), 15 ether);

        /// Bob then recieves shares in the LP according to the below formula
        // Bob Shares = (5 * 10) / (15 - 5) = 5
        assertEq(eETHInstance.shares(bob), 5 ether);
        assertEq(eETHInstance.totalShares(), 15 ether);

        /// Claimable balance of ether is calculated using 
        // (Total_Pooled_Eth * User_Shares) / Total_Shares

        // Bob claimable Ether
        /// (15 * 5) / 15 = 5 ether

        //ALice Claimable Ether
        /// (15 * 10) / 15 = 0 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 10 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5 ether);

        assertEq(eETHInstance.balanceOf(alice), 10 ether);
        assertEq(eETHInstance.balanceOf(bob), 5 ether);

        // Staking Rewards sent to liquidity pool
        /// vm.deal sets the balance of whoever its called on
        /// In this case 10 ether is added as reward 
        vm.deal(address(liquidityPoolInstance), 25 ether);
        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 25 ether);
        assertEq(eETHInstance.totalSupply(), 25 ether);

        // Bob claimable Ether
        /// (25 * 5) / 15 = 8.333333333333333333 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 8.333333333333333333 ether);

        // Alice Claimable Ether
        /// (25 * 10) / 15 = 16.666666666666666666 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 16.666666666666666666 ether);
    
        assertEq(eETHInstance.balanceOf(alice), 16.666666666666666666 ether);
        assertEq(eETHInstance.balanceOf(bob), 8.333333333333333333 ether);

        /// Bob then wraps his eETH to weETH because he wants to stake it in a 3rd party dapp
         startHoax(bob);

        //Approve the wrapped eth contract to spend Bob's eEth
        eETHInstance.approve(address(weEthInstance), 9 ether);
        weEthInstance.wrap(8.333333333333333333 ether);

        // // Bob gets his eETH share amount as weETH
        assertEq(weEthInstance.balanceOf(bob), 4.999999999999999999 ether);
        
        // Another round of rewards enter the LP
        vm.deal(address(liquidityPoolInstance), 30 ether);

        /// Bob's weETH balance remains the same as weETH is non rebasing.
        /// Alice's eETH increases with the rebase.
        assertEq(weEthInstance.balanceOf(bob), 4.999999999999999999 ether);
        assertEq(eETHInstance.balanceOf(alice), 20 ether);
        
        /// Bob then unwraps his weETH and sees his eETH balance has increased from the rebase
        weEthInstance.unwrap(weEthInstance.balanceOf(bob));
        assertEq(eETHInstance.balanceOf(bob), 10 ether);

        /// bob then withdraws his 8 ETH from the pool
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 10 ether);
        uint256 bobETHBalBefore = bob.balance;
        liquidityPoolInstance.withdraw(10 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 0 ether);
        assertEq(bob.balance, bobETHBalBefore + 10 ether);

        vm.stopPrank();

        /// Chad deposits 16 ether into Pool
        startHoax(chad);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        liquidityPoolInstance.deposit{value: 16 ether}(chad, chadProof);
        vm.stopPrank();

        // Chad's 16 ether plus Alice's 20 ether
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 36 ether);

        // EtherFi rolls up 32 ether into a vlaidator and mints the associated NFT's
        startHoax(owner);
        uint256[] memory processedBidIds = liquidityPoolInstance.batchDepositWithBidIds(1, bidIds);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 4 ether);
        assertEq(address(stakingManagerInstance).balance, 32 ether);

        // Generate Deposit Data
        IStakingManager.DepositData[] memory depositDataArray = new IStakingManager.DepositData[](1);
        address etherFiNode = managerInstance.etherfiNodeAddress(processedBidIds[0]);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        depositDataArray[0] = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        // Register the Validator
        liquidityPoolInstance.batchRegisterValidators(_getDepositRoot(), processedBidIds, depositDataArray);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.numValidators(), 1);
        assertEq(address(stakingManagerInstance).balance, 0 ether);

        // Check NFT's are minted corrctly
        assertEq(TNFTInstance.ownerOf(processedBidIds[0]), address(liquidityPoolInstance));
        assertEq(BNFTInstance.ownerOf(processedBidIds[0]), owner);

        /// 1 ETH OF REWARDS COME IN
        vm.deal(address(liquidityPoolInstance), 5 ether);

        // Alice and Chad's deposits rebase 
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 20.555555555555555555 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(chad), 16.444444444444444444 ether);

        /// Chad has a claimable balance of 16.4 ETH but the Pool only has a balance of 5 ETH.
        /// EtherFi should make sure that there is sufficient liquidity in the pool to allow for withdrawals
        vm.expectRevert("Not enough ETH in the liquidity pool");
        vm.prank(chad);
        liquidityPoolInstance.withdraw(16 ether);
        
        // EtherFi deposits a validatos worth (32 ETH) into the pool to allow for users to withdraw
        hoax(owner);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);
        liquidityPoolInstance.deposit{value: 32 ether}(owner, ownerProof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 37 ether);

        // EtherFi sends an exit request for a node to be exited to reclaim the 32 etehr sent to the pool for withdrawals
        vm.startPrank(owner);
        liquidityPoolInstance.sendExitRequests(processedBidIds);

        /// Node exit takes a few days...
        skip(2 days);

        /// EtherFi procceses the node exit and withdraws rewards.
        // Liquidity Pool is the TNFT holder so will get the TNFT rewards
        // EtherFi will get the BNFT Rewards
        // Bob will get the Operator rewards

        uint32[] memory exitTimestamps = new uint32[](1);
        exitTimestamps[0] = uint32(block.timestamp);

        uint256 poolBalBefore = address(liquidityPoolInstance).balance;
        uint256 ownerBalBefore = owner.balance;
        uint256 bobBalBefore = bob.balance;
        uint256 treasuryBalBefore = address(treasuryInstance).balance;

        (uint256 toOperator, uint256 toTNFT, uint256 toBNFT, uint256 toTreasury) = managerInstance.getRewardsPayouts(processedBidIds[0], true, false, true);

        managerInstance.processNodeExit(processedBidIds, exitTimestamps);
        vm.stopPrank();

        assertTrue(IEtherFiNode(etherFiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED);
        assertEq(address(liquidityPoolInstance).balance, poolBalBefore + toTNFT);
        assertEq(owner.balance, ownerBalBefore + toBNFT);
        assertEq(bob.balance, bobBalBefore + toOperator);
        assertEq(address(treasuryInstance).balance, treasuryBalBefore + toTreasury);

        // EtherFi delists the node from the Pool
        uint256[] memory slashingPenalties = new uint256[](1);
        slashingPenalties[0] = 0;

        vm.prank(owner);
        liquidityPoolInstance.processNodeExit(processedBidIds, slashingPenalties);
        assertEq(liquidityPoolInstance.numValidators(), 0);
        console.logUint(eETHInstance.balanceOf(alice));
        // assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 27.77777777777777777 ether);
    }

    /*----- EAP MIGRATION SCENARIO -----*/
    function test_EapMigration() public {
        /// @notice This test uses ETH to test the withdrawal and deposit flow due to the complexity of deploying a local wETH/ERC20 pool for swaps
        /// @notice Gareth has tested the ERC20 deposits on goerli and assures everything works.

        /*
        Alice, Chad all deposit into the Early Adopter Pool
        
        -   Alice claims her funds after the snapshot has been taken. 
            She then deposits her ETH into the Claim Receiver Pool and has her score is set in the score manager contract.
        
        -   Chad withdraws his funds after the snapshot but does not deposit into the CRP losing all his points.
        */

        // Acotrs deposit into EAP
        startHoax(alice);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();

        skip(3 days);

        startHoax(chad);
        earlyAdopterPoolInstance.depositEther{value: 2 ether}();
        vm.stopPrank();

        skip(1 days);

        startHoax(dan);
        earlyAdopterPoolInstance.depositEther{value: 1 ether}();
        vm.stopPrank();


        skip(8 weeks);

        // PAUSE CONTRACTS AND GET READY FOR SNAPSHOT
        vm.startPrank(owner);
        earlyAdopterPoolInstance.pauseContract();
        claimReceiverPoolInstance.pauseContract();
        vm.stopPrank();

        /// SNAPSHOT FROM PYTHON SCRIPT GETS TAKEN HERE
        // Alice's Points are 100224
        // Bob's points are 136850

        uint256 alicePoints = earlyAdopterPoolInstance.calculateUserPoints(
            alice
        );

        uint256 chadPoints = earlyAdopterPoolInstance.calculateUserPoints(chad);
        uint256 danPoints = earlyAdopterPoolInstance.calculateUserPoints(dan);

        /// MERKLE TREE GETS GENERATED AND UPDATED
        vm.prank(owner);
        claimReceiverPoolInstance.updateMerkleRoot(rootMigration2);

        // Unpause CRP to allow for depoists
        vm.startPrank(owner);
        claimReceiverPoolInstance.unPauseContract();
        vm.stopPrank();

        // Alice Withdraws
        vm.startPrank(alice);
        earlyAdopterPoolInstance.withdraw();
        vm.stopPrank();

        // Alice Deposits into the Claim Receiver Pool and receives eETH in return
        bytes32[] memory aliceProof = merkleMigration2.getProof(
            dataForVerification2,
            0
        );
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        claimReceiverPoolInstance.deposit{value: 1 ether}(
            0,
            0,
            0,
            0,
            103680,
            aliceProof,
            slippageArray
        );
        vm.stopPrank();

        assertEq(address(claimReceiverPoolInstance).balance, 0);
        assertEq(address(liquidityPoolInstance).balance, 1 ether);

        // Check that Alice has received eETH
        assertEq(eETHInstance.balanceOf(alice), 1 ether);

        // Check that scores are recorded in Score Manager
        assertEq(
            scoreManagerInstance.scores(0, alice),
            alicePoints
        );


        // Chad withdraws and does not deposit
        // If he does not deposit his points will not be stored in the score manager
        uint256 chadBalanceBeforeWithdrawal = chad.balance;
        uint256 eapBalanceBeforeWithdrawal = address(earlyAdopterPoolInstance)
            .balance;
        vm.prank(chad);
        earlyAdopterPoolInstance.withdraw();
        assertEq(chad.balance, chadBalanceBeforeWithdrawal + 2 ether);
        assertEq(
            address(earlyAdopterPoolInstance).balance,
            eapBalanceBeforeWithdrawal - 2 ether
        );

        // Dan withdraws and does not deposit but gets special approval from ether.Fi to set his score in the score manager
        uint256 danBalanceBeforeWithdrawal = dan.balance;
        eapBalanceBeforeWithdrawal = address(earlyAdopterPoolInstance).balance;
        vm.prank(dan);
        earlyAdopterPoolInstance.withdraw();
        assertEq(dan.balance, danBalanceBeforeWithdrawal + 1 ether);
        assertEq(
            address(earlyAdopterPoolInstance).balance,
            eapBalanceBeforeWithdrawal - 1 ether
        );

        // ether.Fi approves dan to set his score
        vm.prank(owner);
        scoreManagerInstance.setCallerStatus(dan, true);

        vm.prank(dan);
        scoreManagerInstance.setScore(
            0,
            dan,
            danPoints
        );
        assertEq(
            scoreManagerInstance.scores(0, dan),
            danPoints
        );

    }

    /*------ AUCTION / STAKER FLOW ------*/

    // Chad - Bids first with 5 bids of 0.2 ETH
    // Bob - Bids second with 30 bids of 0.2 ETH
    // Chad - Cancels 4 bids
    // Dan - Then stakes once, should be matched with Chad's only bid of 0.2 ETH
    // Dan - Cancels his stake
    // Greg - Stakes 5 times, should be matched with one of Chads and 4 of Bob bids
    // Greg - Registers 5 validators
    function test_AuctionToStakerFlow() public {
        bytes32[] memory chadProof = merkle.getProof(whiteListedAddresses, 5);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            _ipfsHash,
            40
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            chadProof,
            _ipfsHash,
            10
        );

        //-------------------------------------------------------------------------------------------------------------------------------

        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{value: 1 ether}(
            5,
            0.2 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 5);
        assertEq(address(auctionInstance).balance, 1 ether);

        //-------------------------------------------------------------------------------------------------------------------------------

        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{value: 6 ether}(
            30,
            0.2 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 35);
        assertEq(address(auctionInstance).balance, 7 ether);

        //-------------------------------------------------------------------------------------------------------------------------------

        startHoax(chad);
        uint256 chadBalanceBeforeCancelling = chad.balance;

        uint256[] memory bidIdsToCancel = new uint256[](4);
        bidIdsToCancel[0] = chadBidIds[0];
        bidIdsToCancel[1] = chadBidIds[1];
        bidIdsToCancel[2] = chadBidIds[2];
        bidIdsToCancel[3] = chadBidIds[3];
        auctionInstance.cancelBidBatch(bidIdsToCancel);

        (uint256 amount, , , bool isActive) = auctionInstance.bids(2);

        assertEq(auctionInstance.numberOfActiveBids(), 31);
        assertEq(chad.balance, chadBalanceBeforeCancelling + 0.8 ether);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);
        assertEq(address(auctionInstance).balance, 6.2 ether);

        vm.stopPrank();

        //-------------------------------------------------------------------------------------------------------------------------------

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = chadBidIds[4];

        bytes32[] memory danProof = merkle.getProof(whiteListedAddresses, 6);

        startHoax(dan);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            danProof
        );

        (amount, , , isActive) = auctionInstance.bids(chadBidIds[4]);
        address staker = stakingManagerInstance.bidIdToStaker(chadBidIds[4]);

        assertEq(amount, 0.2 ether);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 30);
        assertEq(staker, dan);
        assertEq(address(auctionInstance).balance, 6.2 ether);
        assertEq(address(stakingManagerInstance).balance, 32 ether);

        //-------------------------------------------------------------------------------------------------------------------------------

        uint256 danBalanceBeforeCancelling = dan.balance;

        stakingManagerInstance.cancelDeposit(chadBidIds[4]);

        (amount, , , isActive) = auctionInstance.bids(chadBidIds[4]);
        staker = stakingManagerInstance.bidIdToStaker(chadBidIds[4]);

        assertEq(staker, address(0));
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 31);
        assertEq(address(auctionInstance).balance, 6.2 ether);
        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(dan.balance, danBalanceBeforeCancelling + 32 ether);

        vm.stopPrank();

        //-------------------------------------------------------------------------------------------------------------------------------

        uint256 gregBalanceBeforeStaking = greg.balance;
        bytes32[] memory gregProof = merkle.getProof(whiteListedAddresses, 8);

        startHoax(greg);
        uint256[] memory bidIdArray2 = new uint256[](6);
        bidIdArray2[0] = chadBidIds[4];
        bidIdArray2[1] = bobBidIds[0];
        bidIdArray2[2] = chadBidIds[0];
        bidIdArray2[3] = bobBidIds[1];
        bidIdArray2[4] = bobBidIds[2];
        bidIdArray2[5] = bobBidIds[3];

        uint256[] memory gregProcessedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 192 ether}(
            bidIdArray2,
            gregProof
        );

        staker = stakingManagerInstance.bidIdToStaker(bobBidIds[2]);

        assertEq(staker, greg);
        assertEq(auctionInstance.numberOfActiveBids(), 26);
        assertEq(address(auctionInstance).balance, 6.2 ether);
        assertEq(address(stakingManagerInstance).balance, 160 ether);

        //-------------------------------------------------------------------------------------------------------------------------------

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](gregProcessedBidIds.length);

        for (uint256 i = 0; i < gregProcessedBidIds.length; i++) {
            address node = managerInstance.etherfiNodeAddress(
                gregProcessedBidIds[i]
            );

            root = depGen.generateDepositRoot(
                hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                managerInstance.generateWithdrawalCredentials(node),
                32 ether
            );
            depositDataArray[i] = IStakingManager.DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        }

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), gregProcessedBidIds, depositDataArray);

        for (uint256 i = 0; i < gregProcessedBidIds.length; i++) {
            address gregNode = managerInstance.etherfiNodeAddress(
                gregProcessedBidIds[i]
            );
            assertEq(gregNode.balance, 0.1 ether);
        }

        for (uint256 i = 0; i < gregProcessedBidIds.length; i++) {
            address gregNode = managerInstance.etherfiNodeAddress(
                gregProcessedBidIds[i]
            );
            assertTrue(
                IEtherFiNode(gregNode).phase() ==
                    IEtherFiNode.VALIDATOR_PHASE.LIVE
            );
            assertEq(TNFTInstance.ownerOf(gregProcessedBidIds[i]), greg);
            assertEq(BNFTInstance.ownerOf(gregProcessedBidIds[i]), greg);
        }

        assertEq(address(auctionInstance).balance, 5.2 ether);
        assertEq(address(protocolRevenueManagerInstance).balance, 0.5 ether);
        assertEq(managerInstance.numberOfValidators(), 5);
        assertEq(address(stakingManagerInstance).balance, 0 ether);
    }
}
