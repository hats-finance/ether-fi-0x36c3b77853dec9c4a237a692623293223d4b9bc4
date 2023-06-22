// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract ProtocolRevenueManagerTest is TestSetup {
        
    bytes32[] public proof;
    bytes32[] public aliceProof;
    
    function setUp() public {
        setUpTests();

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        protocolRevenueManagerImplementation.initialize();

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);
        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            50
        );
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            168
        );
        assertEq(
            address(protocolRevenueManagerInstance.etherFiNodesManager()),
            address(managerInstance)
        );
        assertEq(
            address(protocolRevenueManagerInstance.auctionManager()),
            address(auctionInstance)
        );

        vm.startPrank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(_ipfsHash, 5);
        vm.stopPrank();

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );
    }

    function test_changeAuctionRewardParams() public {
        vm.expectRevert("Only admin function");
        protocolRevenueManagerInstance.setAuctionRewardVestingPeriod(1);
        vm.expectRevert("Only admin function");
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(10);

        vm.startPrank(alice);
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            168
        );
        protocolRevenueManagerInstance.setAuctionRewardVestingPeriod(1);
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            1
        );

        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            50
        );
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(10);
        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            10
        );
    }

    function test_Receive() public {
        vm.expectRevert("No Active Validator");
        startHoax(alice);
        (bool sent, ) = address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        assertTrue(sent);
        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );

        vm.expectRevert("No Active Validator");
        (sent, ) = address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        assertTrue(sent);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidIds, aliceProof);

        vm.expectRevert("No Active Validator");
        (sent, ) = address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        assertTrue(sent);
        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        depositDataArray[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(
            zeroRoot,
            bidIds,
            depositDataArray
        );

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            500000000000000001
        );

        (sent, ) = address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        assertTrue(sent);
        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            1500000000000000001
        );
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId, proof);


        IStakingManager.DepositData[]
            memory depositDataArray2 = new IStakingManager.DepositData[](1);

        etherFiNode = managerInstance.etherfiNodeAddress(2);
        root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        depositData = IStakingManager.DepositData({
            publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            depositDataRoot: root,
            ipfsHashForEncryptedValidatorKey: "test_ipfs"
        });

        depositDataArray2[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(
            zeroRoot,
            bidId,
            depositDataArray2
        );

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            1750000000000000001
        );

        (sent, ) = address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        assertTrue(sent);
        vm.stopPrank();

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            2250000000000000001
        );
    }

    function test_GetAccruedAuctionRevenueRewards() public {
        startHoax(alice);

        uint256[] memory bidId = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId, aliceProof);
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        depositDataArray[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(
            zeroRoot,
            bidId,
            depositDataArray
        );
        vm.stopPrank();

        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId[0]
            ),
            0.5 ether
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256[] memory bidIds2 = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidIds2, proof);

        IStakingManager.DepositData[]
            memory depositDataArray2 = new IStakingManager.DepositData[](1);

        etherFiNode = managerInstance.etherfiNodeAddress(2);
        root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        depositData = IStakingManager.DepositData({
            publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            depositDataRoot: root,
            ipfsHashForEncryptedValidatorKey: "test_ipfs"
        });

        depositDataArray2[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(
            zeroRoot,
            bidIds2,
            depositDataArray2
        );
        vm.stopPrank();

        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId[0]
            ),
            0.75 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidIds2[0]
            ),
            0.25 ether
        );
    }

    function test_AddAuctionRevenueWorksAndFailsCorrectly() public {
        hoax(address(auctionInstance));
        vm.expectRevert("No Active Validator");
        protocolRevenueManagerInstance.addAuctionRevenue{value: 1 ether}(1);

        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        startHoax(nodeOperator);

        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        vm.stopPrank();

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);
        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        startHoax(alice);
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            aliceProof
        );
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        
        depositDataArray[0] = depositData;
        
        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        stakingManagerInstance.batchRegisterValidators(
            zeroRoot,
            bidId,
            depositDataArray
        );
        vm.stopPrank();

        // 0.1 ether
        //  -> 0.05 ether to its etherfi Node contract
        //  -> 0.05 ether to the protocol revenue manager contract
        assertEq(address(protocolRevenueManagerInstance).balance, 0.05 ether);
        assertEq(address(etherFiNode).balance, 0.05 ether);
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId[0]
            ),
            0.05 ether
        );
        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.05 ether + 1
        );

        hoax(address(managerInstance));
        uint256 revenue = protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(revenue, 0.05 ether);
        assertEq(address(protocolRevenueManagerInstance).balance, 0 ether);
        assertEq(address(etherFiNode).balance, 0.1 ether);

        hoax(address(managerInstance));
        revenue = protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(revenue, 0 ether); // can't double dip
        assertEq(address(protocolRevenueManagerInstance).balance, 0 ether);
        assertEq(address(etherFiNode).balance, 0.1 ether);

        // Expect no revenue if node is considered exited or withdraw
        vm.prank(address(stakingManagerInstance));
        managerInstance.setEtherFiNodePhase(bidId[0], IEtherFiNode.VALIDATOR_PHASE.EXITED);

        vm.prank(address(managerInstance));
        revenue = protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(revenue, 0);

        vm.prank(address(stakingManagerInstance));
        managerInstance.setEtherFiNodePhase(bidId[0], IEtherFiNode.VALIDATOR_PHASE.FULLY_WITHDRAWN);
        vm.prank(address(managerInstance));
        revenue = protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(revenue, 0);

        hoax(address(auctionInstance));
        vm.expectRevert(
            "addAuctionRevenue is already processed for the validator."
        );
        protocolRevenueManagerInstance.addAuctionRevenue{value: 1 ether}(
            bidId[0]
        );
    }

    function test_modifiers() public {
        hoax(alice);
        vm.expectRevert("Only auction manager function");
        protocolRevenueManagerInstance.addAuctionRevenue(0);

        vm.expectRevert("Only etherFiNodesManager function");
        protocolRevenueManagerInstance.distributeAuctionRevenue(0);

        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setAuctionManagerAddress(alice);

        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(alice);
    }
}
