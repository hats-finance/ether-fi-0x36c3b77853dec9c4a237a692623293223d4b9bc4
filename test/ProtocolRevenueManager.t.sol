// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract ProtocolRevenueManagerTest is TestSetup {
    function setUp() public {
        setUpTests();

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

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        vm.startPrank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);
        vm.stopPrank();

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );
    }

    function test_changeAuctionRewardParams() public {
        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setAuctionRewardVestingPeriod(1);
        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(10);

        vm.startPrank(owner);
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
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );

        vm.expectRevert("No Active Validator");
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidIds);

        vm.expectRevert("No Active Validator");
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        stakingManagerInstance.registerValidator(
            _getDepositRoot(),
            bidIds[0],
            depositData
        );

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            500000000000000001
        );

        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

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

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId);

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
        stakingManagerInstance.registerValidator(
            _getDepositRoot(),
            bidId[0],
            depositData
        );

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            1750000000000000001
        );

        address(protocolRevenueManagerInstance).call{value: 1 ether}("");
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
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId);
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        stakingManagerInstance.registerValidator(
            _getDepositRoot(),
            bidId[0],
            depositData
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
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidIds2);
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
        stakingManagerInstance.registerValidator(
            _getDepositRoot(),
            bidIds2[0],
            depositData
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
            bidIdArray
        );
        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });
        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        stakingManagerInstance.registerValidator(
            _getDepositRoot(),
            bidId[0],
            depositData
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

        // 3
        hoax(address(auctionInstance));
        vm.expectRevert(
            "addAuctionRevenue is already processed for the validator."
        );
        protocolRevenueManagerInstance.addAuctionRevenue{value: 1 ether}(
            bidId[0]
        );

        hoax(address(managerInstance));
        protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(address(protocolRevenueManagerInstance).balance, 0 ether);
        assertEq(address(etherFiNode).balance, 0.1 ether);

        hoax(address(managerInstance));
        protocolRevenueManagerInstance.distributeAuctionRevenue(bidId[0]);
        assertEq(address(protocolRevenueManagerInstance).balance, 0 ether);
        assertEq(address(etherFiNode).balance, 0.1 ether);
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
