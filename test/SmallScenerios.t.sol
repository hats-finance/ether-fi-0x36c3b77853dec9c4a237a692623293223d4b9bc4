// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract SmallScenariosTest is TestSetup {
    uint256[] public slippageArray;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public chadProof;
    bytes32[] public danProof;
    bytes32[] public ownerProof;

    function setUp() public {
        setUpTests();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        chadProof = merkle.getProof(whiteListedAddresses, 5);
        danProof = merkle.getProof(whiteListedAddresses, 6);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);
    }
    
    /*
    Alice, Bob and Chad all deposit into the liquidity pool.
    Alice and Chad keep their eETH to earn rebasing rewards.
    Bob wraps his eETH into weETH to use in other DeFi applications.
    Once Rewards are distrubuted, Bob decides to unwrap his weETH back to eETH.
    There's more the 32 eth in the pool so EtherFi rolls it up into a validator.
    Chad then wants to withdraw his 17 ETH but there is < Chad's balance in the pool.
    EtherFi deposits their own ETH to keep the pool solvent and allow withdrawals.
    EtherFi requests an exit for the TNFT that was minted.
    Once the nodes exit is observed, EtherFi processes the node's exit from the EtherFiNodesManager.
    Rewards are distributed.
    
    */ 
    function test_EEthWeTHLpScenarios() public {
        // bids to match with later staking 
        bobProof = merkle.getProof(whiteListedAddresses, 4);

        startHoax(bob);
        nodeOperatorManagerInstance.registerNodeOperator(_ipfsHash, 40);
        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(5, 0.2 ether);
        vm.stopPrank();

        //-------------------------------------------------------------------------------------------------------------------------------
        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0 ether);

        /// Alice confirms she is not a US or Canadian citizen and deposits 10 ETH into the pool.
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        /// Bob then comes along, confirms he is not a US or Canadian citizen and deposits 5 ETH into the pool.
        startHoax(bob);
        vm.expectRevert("Incorrect hash");
        regulationsManagerInstance.confirmEligibility("INCORRECT HASH");

        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 5 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 15 ether);
        assertEq(eETHInstance.totalSupply(), 15 ether);

        assertEq(eETHInstance.shares(bob), 5 ether);
        assertEq(eETHInstance.totalShares(), 15 ether);

        /// Claimable balance of ether is calculated using 
        // (Total_Pooled_Eth * User_Shares) / Total_Shares

        // Bob claimable Ether
        /// (15 * 5) / 15 = 5 ether

        //ALice Claimable Ether
        /// (15 * 10) / 15 = 10 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 10 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5 ether);

        assertEq(eETHInstance.balanceOf(alice), 10 ether);
        assertEq(eETHInstance.balanceOf(bob), 5 ether);

        /// Bob then wraps his eETH to weETH because he wants to stake it in a 3rd party dapp
         startHoax(bob);

        //Approve the wrapped eth contract to spend Bob's eEth
        eETHInstance.approve(address(weEthInstance), 5 ether);
        weEthInstance.wrap(5 ether);

        // // Bob gets his eETH share amount as weETH
        assertEq(weEthInstance.balanceOf(bob), 5 ether);

        vm.stopPrank();

        /// Chad confirms he is not a US or Canadian citizen and deposits 17 ether into Pool
        startHoax(chad);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 15 ether}(chad, chadProof);
        vm.stopPrank();

        // Chad's 15 ETH + Alice's 10ETH + Bob's 5ETH
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 30 ether);

        // EtherFi rolls up 32 ether into a vlaidator and mints the associated NFT's
        vm.deal(owner, 4 ether);
        startHoax(owner);
        uint256[] memory processedBidIds = liquidityPoolInstance.batchDepositWithBidIds{value: 2 ether}(1, bidIds, getWhitelistMerkleProof(9));

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0 ether);
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

        /// STAKING REWARDS COME IN DAILY
        // EtherFi sets the accured staking rewards in the Liquidity Pool.
        skip(1 days);
        
        startHoax(owner);
        liquidityPoolInstance.setAccruedEther(1 ether);
        vm.stopPrank();

        // Total pooled ETH = 30 ETH in the validator + 1 ETH Staking rewards
        // - Alice's 10 ETH -> 10 + 1 * (10/30) ETH = 10.33333
        // - Bob's   5 ETH ->  5 + 1 * (5/30) ETH = 5.16666
        // - Chad's 15 ETH -> 15 + 1 * (15/30) ETH = 15.5
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 31 ether);
        
        // Alice and Chad's deposits rebase 
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 10.333333333333333333 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(chad), 15.500000000000000000 ether);

        // Bob unwraps his weETH to see his rebasing rewards 
        assertEq(weEthInstance.balanceOf(bob), 5 ether);
        vm.prank(bob);
        weEthInstance.unwrap(5 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5.166666666666666665 ether);
        
        /// Chad wnats to withdraw his ETH from the pool.
        /// He has a claimable balance of 15.5 ETH but the Pool only has a balance of 0.0453125 ETH.
        /// EtherFi should make sure that there is sufficient liquidity in the pool to allow for withdrawals
        vm.expectRevert("Not enough ETH in the liquidity pool");
        vm.prank(chad);
        liquidityPoolInstance.withdraw(chad, 15.5 ether);
        
        // EtherFi deposits a validators worth (32 ETH) into the pool to allow users to withdraw
        vm.deal(owner, 100 ether);
        vm.startPrank(owner);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 31 ether);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 32 ether}(owner, ownerProof);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 31 ether + 32 ether);
        vm.stopPrank();
        
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(chad), 15.5 ether);
        // Chad withdraws 
        vm.prank(chad);
        liquidityPoolInstance.withdraw(chad, 15.5 ether);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 47.5 ether); // 63 - 15.5 = 47.5
        assertEq(address(liquidityPoolInstance).balance, 16.5 ether); // 32 - 15.5 = 16.5

        // EtherFi sends an exit request for a node to be exited to reclaim the 32 ether sent to the pool for withdrawals
        {
            vm.startPrank(owner);
            liquidityPoolInstance.sendExitRequests(processedBidIds);

            /// Node exit takes a few days...
            skip(10 days);

            // The node contract receives the ETH (principal + rewards) from the beacon chian
            address node = managerInstance.etherfiNodeAddress(processedBidIds[0]);
            uint256 totalStakingRewardsForOneEtherRewardsForTnft = 1 ether * uint256(100 * 32) / uint256(90 * 29);
            vm.deal(address(node), address(node).balance + 32 ether + totalStakingRewardsForOneEtherRewardsForTnft);

            // ether.fi procceses the node exit.
            uint32[] memory exitTimestamps = new uint32[](1);
            exitTimestamps[0] = uint32(block.timestamp);
            managerInstance.processNodeExit(processedBidIds, exitTimestamps);

            (uint256 toOperator, uint256 toTNFT, uint256 toBNFT, uint256 toTreasury) = managerInstance.getFullWithdrawalPayouts(processedBidIds[0]);
            assertEq(toTNFT, 30 ether + 1 ether - 1);

            vm.stopPrank();
        }

        vm.prank(owner);

        // ether.fi process the node exit from the LP
        uint256[] memory slashingPenalties = new uint256[](1);
        slashingPenalties[0] = 0;

        // (30 ETH + @ ETH) enters the pool from the ether.fi node contract
        liquidityPoolInstance.processNodeExit(processedBidIds, slashingPenalties);

        assertEq(liquidityPoolInstance.numValidators(), 0);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 10.333333333333333333 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5.166666666666666665 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(chad), 0.000000000000000001 ether);
    }

    /*----- EAP MIGRATION SCENARIO -----*/
    // function test_EapMigration() public {
    //     /// @notice This test uses ETH to test the withdrawal and deposit flow due to the complexity of deploying a local wETH/ERC20 pool for swaps
    //     /// @notice Gareth has tested the ERC20 deposits on goerli and assures everything works.

    //     /*
    //     Alice, Chad all deposit into the Early Adopter Pool
        
    //     -   Alice claims her funds after the snapshot has been taken. 
    //         She then deposits her ETH into the Claim Receiver Pool and has her score is set in the score manager contract.
        
    //     -   Chad withdraws his funds after the snapshot but does not deposit into the CRP losing all his points.
    //     */

    //     // Acotrs deposit into EAP
    //     startHoax(alice);
    //     earlyAdopterPoolInstance.depositEther{value: 1 ether}();
    //     vm.stopPrank();

    //     skip(3 days);

    //     startHoax(chad);
    //     earlyAdopterPoolInstance.depositEther{value: 2 ether}();
    //     vm.stopPrank();

    //     skip(1 days);

    //     startHoax(dan);
    //     earlyAdopterPoolInstance.depositEther{value: 1 ether}();
    //     vm.stopPrank();


    //     skip(8 weeks);

    //     // PAUSE CONTRACTS AND GET READY FOR SNAPSHOT
    //     vm.startPrank(owner);
    //     earlyAdopterPoolInstance.pauseContract();
    //     claimReceiverPoolInstance.pauseContract();
    //     vm.stopPrank();

    //     /// SNAPSHOT FROM PYTHON SCRIPT GETS TAKEN HERE
    //     // Alice's Points are 103680 * 1e9 
    //     // Bob's points are 136850

    //     uint256 chadPoints = earlyAdopterPoolInstance.calculateUserPoints(chad);
    //     uint256 danPoints = earlyAdopterPoolInstance.calculateUserPoints(dan);

    //     /// MERKLE TREE GETS GENERATED AND UPDATED
    //     vm.prank(owner);
    //     claimReceiverPoolInstance.updateMerkleRoot(rootMigration2);

    //     // Unpause CRP to allow for depoists
    //     vm.startPrank(owner);
    //     claimReceiverPoolInstance.unPauseContract();
    //     vm.stopPrank();

    //     // Alice Withdraws
    //     vm.startPrank(alice);
    //     earlyAdopterPoolInstance.withdraw();
    //     vm.stopPrank();

    //     // Alice Deposits into the Claim Receiver Pool and receives eETH in return
    //     bytes32[] memory aliceProof = merkleMigration2.getProof(
    //         dataForVerification2,
    //         0
    //     );
    //     vm.startPrank(alice);
    //     regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
    //     claimReceiverPoolInstance.deposit{value: 1 ether}(
    //         0,
    //         0,
    //         0,
    //         0,
    //         103680 * 1e9,
    //         aliceProof,
    //         slippageLimit
    //     );
    //     vm.stopPrank();

    //     assertEq(address(claimReceiverPoolInstance).balance, 0);
    //     assertEq(address(liquidityPoolInstance).balance, 1 ether);

    //     // Check that Alice has received meETH
    //     assertEq(meEthInstance.balanceOf(alice), 1 ether);

    //     // Chad withdraws and does not deposit
    //     uint256 chadBalanceBeforeWithdrawal = chad.balance;
    //     uint256 eapBalanceBeforeWithdrawal = address(earlyAdopterPoolInstance)
    //         .balance;
    //     vm.prank(chad);
    //     earlyAdopterPoolInstance.withdraw();
    //     assertEq(chad.balance, chadBalanceBeforeWithdrawal + 2 ether);
    //     assertEq(
    //         address(earlyAdopterPoolInstance).balance,
    //         eapBalanceBeforeWithdrawal - 2 ether
    //     );

    //     // Dan withdraws and does not deposit
    //     uint256 danBalanceBeforeWithdrawal = dan.balance;
    //     eapBalanceBeforeWithdrawal = address(earlyAdopterPoolInstance).balance;
    //     vm.prank(dan);
    //     earlyAdopterPoolInstance.withdraw();
    //     assertEq(dan.balance, danBalanceBeforeWithdrawal + 1 ether);
    //     assertEq(
    //         address(earlyAdopterPoolInstance).balance,
    //         eapBalanceBeforeWithdrawal - 1 ether
    //     );
    // }

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
            _ipfsHash,
            40
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
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
