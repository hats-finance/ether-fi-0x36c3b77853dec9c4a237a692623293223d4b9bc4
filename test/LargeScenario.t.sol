// // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract LargeScenariosTest is TestSetup {

    bytes IPFS_Hash = "QmYsfDjQZfnSQkNyA4eVwswhakCusAx4Z6bzF89FZ91om3";

    function setUp() public {
        setUpTests();
    }

    function test_LargeScenarioOne() public {
        /* 
        Alice, Bob, Chad - Operators
        Dan, Elvis, Greg, - Stakers
        */

        /// Register Node Operators
        bytes32[] memory emptyProof = new bytes32[](0);
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);
        bytes32[] memory chadProof = merkle.getProof(whiteListedAddresses, 5);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            IPFS_Hash,
            1000
        );

        vm.prank(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            IPFS_Hash,
            4000
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            chadProof,
            IPFS_Hash,
            6000
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            emptyProof,
            IPFS_Hash,
            100
        );

        /// Actors Bid
        hoax(alice);
        uint256[] memory aliceBidIds = auctionInstance.createBid{value: 0.05 ether}(10, 0.005 ether);
        assertEq(aliceBidIds.length, 10);
        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{value: 0.1 ether}(50, 0.002 ether);
        assertEq(bobBidIds.length, 50);
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{value: 0.5 ether}(100, 0.005 ether);
        assertEq(chadBidIds.length, 100);
        vm.expectRevert("Only whitelisted addresses");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.5 ether}(100, 0.005 ether);

        assertEq(address(auctionInstance).balance, 0.65 ether);

        /// Actors Stake
        hoax(dan);
        uint256[] memory danProcessedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(aliceBidIds);
        assertEq(danProcessedBidIds.length, 1);
        assertEq(danProcessedBidIds[0], aliceBidIds[0]);
        address staker = stakingManagerInstance.bidIdToStaker(danProcessedBidIds[0]);
        assertEq(staker, dan);
        bool isActive = auctionInstance.isBidActive(aliceBidIds[0]);
        assertFalse(isActive);
        address danNode = managerInstance.etherfiNodeAddress(danProcessedBidIds[0]);
        assert(danNode != address(0));
        assertTrue(IEtherFiNode(danNode).phase() == IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED);

        assertEq(address(stakingManagerInstance).balance, 32 ether);

        hoax(elvis);
        // 10 Deposits but only 9 bids
        uint256 balanceBefore = elvis.balance;
        uint256[] memory elvisProcessedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 320 ether}(aliceBidIds);
        assertEq(elvisProcessedBidIds.length, 9);
        // staking manager balance should be 320 ether. 320 ether - 32 ether (1 deposit) + 32 ether from previous deposit
        assertEq(address(stakingManagerInstance).balance, 320 ether);
        assertEq(elvis.balance, balanceBefore - 288 ether);
        isActive = auctionInstance.isBidActive(aliceBidIds[9]);
        assertFalse(isActive);

        // Cancel a deposit
        vm.prank(elvis);
        balanceBefore = elvis.balance;
        stakingManagerInstance.cancelDeposit(elvisProcessedBidIds[0]);
        assertTrue(auctionInstance.isBidActive(elvisProcessedBidIds[0]));
        assertEq(address(stakingManagerInstance).balance, 320 ether - 32 ether);
        assertEq(elvis.balance, balanceBefore + 32 ether);

        hoax(greg);
        uint256[] memory gregProcessedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(aliceBidIds);
        assertEq(gregProcessedBidIds.length, 1);

        /// Register Validators
        // generate deposit data
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(danNode),
            32 ether
        );
        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        staker = stakingManagerInstance.bidIdToStaker(danProcessedBidIds[0]);
        assertEq(staker, dan);

        startHoax(dan);
        stakingManagerInstance.registerValidator(_getDepositRoot(), danProcessedBidIds[0], depositData);
        vm.stopPrank();

        assertEq(address(stakingManagerInstance).balance, 288 ether);
        assertTrue(IEtherFiNode(danNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE);
        assertEq(TNFTInstance.ownerOf(danProcessedBidIds[0]), dan);
        assertEq(BNFTInstance.ownerOf(danProcessedBidIds[0]), dan);

        assertEq(managerInstance.numberOfValidators(), 1);

        // Bid amount gets distributed
        assertEq(address(auctionInstance).balance, 0.65 ether - 0.005 ether);
        assertEq(danNode.balance, 0.0025 ether);
        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 0.0025 ether + 1);
        assertEq(EtherFiNode(danNode).localRevenueIndex(), 1);

        // Batch register validators
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](elvisProcessedBidIds.length);

        for(uint256 i = 0; i < elvisProcessedBidIds.length; i++) {
            address node = managerInstance.etherfiNodeAddress(elvisProcessedBidIds[i]);

            root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(node),
            32 ether
        );
        depositDataArray[i] = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        }

        console.log(elvis);
        console.log(greg);
        console.log(dan);
        console.log(owner);
        console.log(alice);
        console.log(bob);
        console.log(chad);

        for(uint256 i = 0; i < elvisProcessedBidIds.length; i++) {
            staker = stakingManagerInstance.bidIdToStaker(elvisProcessedBidIds[i]);
            assertEq(staker, elvis);
        }

        // startHoax(dan);
        // stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), elvisProcessedBidIds, depositDataArray);

        // assertEq(address(stakingManagerInstance).balance, 32 ether);
        // for(uint256 i = 0; i < elvisProcessedBidIds.length; i ++){
        //     address elvisNode = managerInstance.etherfiNodeAddress(elvisProcessedBidIds[i]);
        //     assertTrue(IEtherFiNode(elvisNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE);
        //     assertEq(TNFTInstance.ownerOf(elvisProcessedBidIds[i]), elvis);
        //     assertEq(BNFTInstance.ownerOf(elvisProcessedBidIds[i]), elvis);

        // }
    }
}
