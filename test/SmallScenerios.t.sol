// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract SmallScenariosTest is TestSetup {
    function setUp() public {
        setUpTests();
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
            aliceProof
        );
        vm.stopPrank();

        assertEq(address(claimReceiverPoolInstance).balance, 0);
        assertEq(address(liquidityPoolInstance).balance, 1 ether);

        // Check that Alice has received eETH
        assertEq(eETHInstance.balanceOf(alice), 1 ether);

        // Check that scores are recorded in Score Manager
        assertEq(
            scoreManagerInstance.scores(0, alice),
            bytes32(bytes(abi.encode(alicePoints)))
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
            bytes32(abi.encodePacked(danPoints))
        );
        assertEq(
            scoreManagerInstance.scores(0, dan),
            bytes32(bytes(abi.encode(danPoints)))
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

        startHoax(dan);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray
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

        startHoax(greg);
        uint256[] memory bidIdArray2 = new uint256[](6);
        bidIdArray2[0] = chadBidIds[4];
        bidIdArray2[1] = bobBidIds[0];
        bidIdArray2[2] = chadBidIds[0];
        bidIdArray2[3] = bobBidIds[1];
        bidIdArray2[4] = bobBidIds[2];
        bidIdArray2[5] = bobBidIds[3];

        uint256[] memory gregProcessedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 192 ether}(
            bidIdArray2
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
