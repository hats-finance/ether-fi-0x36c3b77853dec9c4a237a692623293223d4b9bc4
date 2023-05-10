// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console.sol";

contract StakingManagerTest is TestSetup {
    event StakeDeposit(
        address indexed staker,
        uint256 bidId,
        address withdrawSafe
    );
    event DepositCancelled(uint256 id);
    event ValidatorRegistered(
        address indexed operator,
        address indexed bNftOwner,
        address indexed tNftOwner,
        uint256 validatorId,
        bytes validatorPubKey,
        string ipfsHashForEncryptedValidatorKey
    );

    function setUp() public {
        setUpTests();
    }

     function test_DisableInitializer() public {
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        stakingManagerImplementation.initialize(address(auctionInstance));
    }

    function test_fake() public {
        console.logBytes32(_getDepositRoot());
    }

    function test_StakingManagerContractInstantiatedCorrectly() public {
        assertEq(stakingManagerInstance.stakeAmount(), 32 ether);
        assertEq(stakingManagerInstance.owner(), owner);
    }

    function test_GenerateWithdrawalCredentialsCorrectly() public {
        address exampleWithdrawalAddress = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        bytes memory withdrawalCredential = managerInstance
            .generateWithdrawalCredentials(exampleWithdrawalAddress);
        // Generated with './deposit new-mnemonic --eth1_withdrawal_address 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931'
        bytes
            memory trueOne = hex"010000000000000000000000cd5ebc2dd4cb3dc52ac66ceecc72c838b40a5931";
        assertEq(withdrawalCredential.length, trueOne.length);
        assertEq(keccak256(withdrawalCredential), keccak256(trueOne));
    }

    function test_DepositOneWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];
        vm.stopPrank();

        startHoax(owner);
        stakingManagerInstance.enableWhitelist();
        vm.expectRevert("User is not whitelisted");
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        stakingManagerInstance.disableWhitelist();
        vm.stopPrank();
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(1);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

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
        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId, depositDataArray);

        uint256 validatorId = bidId[0];
        uint256 winningBid = bidId[0];
        address staker = stakingManagerInstance.bidIdToStaker(validatorId);
        address etherfiNode = managerInstance.etherfiNodeAddress(validatorId);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(stakingManagerInstance.stakeAmount(), 32 ether);
        assertEq(winningBid, bidId[0]);
        assertEq(validatorId, bidId[0]);

        assertEq(
            IEtherFiNode(etherfiNode).ipfsHashForEncryptedValidatorKey(),
            depositDataArray[0].ipfsHashForEncryptedValidatorKey
        );
        assertEq(
            managerInstance.ipfsHashForEncryptedValidatorKey(validatorId),
            depositDataArray[0].ipfsHashForEncryptedValidatorKey
        );
    }

    function test_BatchDepositWithBidIdsFailsIFInvalidDepositAmount() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.batchDepositWithBidIds{value: 0.033 ether}(
            bidIdArray,
            proof
        );
    }

    function test_BatchDepositWithBidIdsFailsIfNotEnoughActiveBids() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        vm.expectRevert("No bids available at the moment");
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
    }

    function test_BatchDepositWithBidIdsFailsIfNoIdsProvided() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

        uint256[] memory bidIdArray = new uint256[](0);

        vm.expectRevert("No bid Ids provided");
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
    }

    function test_BatchDepositWithBidIdsFailsIfPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
    }

    function test_BatchDepositWithIdsSimpleWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;
        vm.stopPrank();

        vm.startPrank(owner);
        stakingManagerInstance.enableWhitelist();
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        assertEq(auctionInstance.numberOfActiveBids(), 19);

        (uint256 amount, , , bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        (amount, , , isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, true);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        assertEq(address(stakingManagerInstance).balance, 32 ether);
    }

    function test_BatchDepositWithIdsComplexWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        assertEq(auctionInstance.numberOfActiveBids(), 20);
        assertEq(address(auctionInstance).balance, 3 ether);

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        uint256 userBalanceBefore = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        assertEq(auctionInstance.numberOfActiveBids(), 19);

        (uint256 amount, , , bool isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(7);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        (amount, , , isActive) = auctionInstance.bids(20);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, true);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, true);

        uint256[] memory bidIdArray2 = new uint256[](10);
        bidIdArray2[0] = 1;
        bidIdArray2[1] = 3;
        bidIdArray2[2] = 6;
        bidIdArray2[3] = 7;
        bidIdArray2[4] = 8;
        bidIdArray2[5] = 13;
        bidIdArray2[6] = 11;
        bidIdArray2[7] = 12;
        bidIdArray2[8] = 19;
        bidIdArray2[9] = 20;

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray2,
            proof
        );

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            userBalanceBefore - 64 ether
        );
        assertEq(auctionInstance.numberOfActiveBids(), 18);

        (amount, , , isActive) = auctionInstance.bids(1);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);

        (amount, , , isActive) = auctionInstance.bids(13);
        assertEq(amount, 0.2 ether);
        assertEq(isActive, true);

        (amount, , , isActive) = auctionInstance.bids(3);
        assertEq(amount, 0.1 ether);
        assertEq(isActive, false);
    }

    function test_RegisterValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        vm.stopPrank();

        vm.prank(owner);
        bytes32 root = _getDepositRoot();
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.batchRegisterValidators(root, bidId, depositDataArray);
    }

    function test_RegisterValidatorFailsIfIncorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);
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

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidIdArray, depositDataArray);
        vm.stopPrank();

        bytes32 depositRoot = _getDepositRoot();
        vm.expectRevert("Incorrect phase");
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        stakingManagerInstance.batchRegisterValidators(depositRoot, bidIdArray, depositDataArray);
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        uint256[] memory processedBidIds = stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);
        bytes32 depositRoot = _getDepositRoot();
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.batchRegisterValidators(depositRoot, processedBidIds, depositDataArray);
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(1);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);

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

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId, depositDataArray);

        uint256 selectedBidId = bidId[0];
        etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);

        assertEq(address(protocolRevenueManagerInstance).balance, 0.05 ether);
        assertEq(selectedBidId, 1);
        assertEq(managerInstance.numberOfValidators(), 1);
        assertEq(address(managerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0);

        address operatorAddress = auctionInstance.getBidOwner(bidId[0]);
        assertEq(operatorAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        address safeAddress = managerInstance.etherfiNodeAddress(bidId[0]);
        assertEq(safeAddress, etherFiNode);

        assertEq(
            BNFTInstance.ownerOf(bidId[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(bidId[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            BNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            1
        );
        assertEq(
            TNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            1
        );
    }

    function test_BatchRegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        uint256[] memory processedBidIds = stakingManagerInstance
            .batchDepositWithBidIds{value: 128 ether}(bidIdArray, proof);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](4);

        for (uint256 i = 0; i < processedBidIds.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                processedBidIds[i]
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

        assertEq(address(auctionInstance).balance, 3 ether);
        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), 
            processedBidIds,
            depositDataArray
        );

        assertEq(address(protocolRevenueManagerInstance).balance, 0.2 ether);
        assertEq(address(auctionInstance).balance, 2.6 ether);

        assertEq(
            BNFTInstance.ownerOf(processedBidIds[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            BNFTInstance.ownerOf(processedBidIds[1]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            BNFTInstance.ownerOf(processedBidIds[2]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            BNFTInstance.ownerOf(processedBidIds[3]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(processedBidIds[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(processedBidIds[1]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(processedBidIds[2]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(processedBidIds[3]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );

        assertEq(managerInstance.numberOfValidators(), 4);
    }

    function test_BatchRegisterValidatorFailsIfArrayLengthAreNotEqual() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        uint256[] memory bidIdArray = new uint256[](10);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;
        bidIdArray[4] = 8;
        bidIdArray[5] = 9;
        bidIdArray[6] = 11;
        bidIdArray[7] = 12;
        bidIdArray[8] = 19;
        bidIdArray[9] = 20;

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](9);
        depositDataArray[0] = test_data;
        depositDataArray[1] = test_data_2;
        depositDataArray[2] = test_data;
        depositDataArray[3] = test_data_2;
        depositDataArray[4] = test_data;
        depositDataArray[5] = test_data_2;
        depositDataArray[6] = test_data;
        depositDataArray[7] = test_data_2;
        depositDataArray[8] = test_data;

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        assertEq(address(auctionInstance).balance, 3 ether);
        
        bytes32 root = _getDepositRoot();
        vm.expectRevert("Array lengths must match");
        stakingManagerInstance.batchRegisterValidators(root, 
            bidIdArray,
            depositDataArray
        );
    }

    function test_BatchRegisterValidatorFailsIfIncorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        uint256[] memory bidIdArray = new uint256[](4);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 6;
        bidIdArray[3] = 7;

        uint256[] memory processedBidIds = stakingManagerInstance
            .batchDepositWithBidIds{value: 128 ether}(bidIdArray, proof);

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](4);

        for (uint256 i = 0; i < processedBidIds.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                processedBidIds[i]
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

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), 
            processedBidIds,
            depositDataArray
        );

        bytes32 root = _getDepositRoot();
        vm.expectRevert("Incorrect phase");
        stakingManagerInstance.batchRegisterValidators(root, 
            bidIdArray,
            depositDataArray
        );
    }

    function test_BatchRegisterValidatorFailsIfMoreThan16Registers() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 100);

        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        }
        for (uint256 x = 0; x < 10; x++) {
            auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);
        }

        uint256[] memory bidIdArray = new uint256[](27);
        bidIdArray[0] = 1;
        bidIdArray[1] = 2;
        bidIdArray[2] = 3;
        bidIdArray[3] = 4;
        bidIdArray[4] = 5;
        bidIdArray[5] = 6;
        bidIdArray[6] = 7;
        bidIdArray[7] = 8;
        bidIdArray[8] = 9;
        bidIdArray[9] = 10;
        bidIdArray[10] = 11;
        bidIdArray[11] = 12;
        bidIdArray[12] = 13;
        bidIdArray[13] = 14;
        bidIdArray[14] = 15;
        bidIdArray[15] = 16;
        bidIdArray[16] = 17;
        bidIdArray[17] = 18;
        bidIdArray[18] = 19;
        bidIdArray[19] = 20;
        bidIdArray[20] = 21;
        bidIdArray[21] = 22;
        bidIdArray[22] = 23;
        bidIdArray[23] = 24;
        bidIdArray[24] = 25;
        bidIdArray[25] = 26;
        bidIdArray[26] = 27;

        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](27);


        for (uint256 i = 0; i < bidIdArray.length; i++) {
            address etherFiNode = managerInstance.etherfiNodeAddress(
                bidIdArray[i]
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

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        assertEq(address(auctionInstance).balance, 3 ether);

        bytes32 root = _getDepositRoot();
        vm.expectRevert("Too many validators");
        stakingManagerInstance.batchRegisterValidators(root, 
            bidIdArray,
            depositDataArray
        );
    }

    function test_cancelDepositFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.batchCancelDeposit(bidId);

        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.batchCancelDeposit(bidId);
    }

    function test_cancelDepositFailsIfDepositDoesNotExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        stakingManagerInstance.batchCancelDeposit(bidId);

        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.batchCancelDeposit(bidId);
    }

    function test_cancelDepositFailsIfIncorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);
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

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId, depositDataArray);

        vm.expectRevert("Incorrect phase");
        stakingManagerInstance.batchCancelDeposit(bidId);
    }

    function cancelDepositFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.batchCancelDeposit(bidIdArray);
    }

    function test_cancelDepositWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);
        uint256[] memory bidId2 = auctionInstance.createBid{value: 0.3 ether}(
            1,
            0.3 ether
        );
        auctionInstance.createBid{value: 0.2 ether}(1, 0.2 ether);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        uint256 selectedBidId = bidId2[0];
        address staker = stakingManagerInstance.bidIdToStaker(bidId2[0]);
        address etherFiNode = managerInstance.etherfiNodeAddress(bidId2[0]);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(selectedBidId, bidId2[0]);
        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        (uint256 bidAmount, , address bidder, bool isActive) = auctionInstance
            .bids(selectedBidId);

        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.batchCancelDeposit(bidId2);
        assertEq(managerInstance.etherfiNodeAddress(bidId2[0]), address(0));
        assertEq(stakingManagerInstance.bidIdToStaker(bidId2[0]), address(0));
        assertTrue(
            IEtherFiNode(etherFiNode).phase() ==
                IEtherFiNode.VALIDATOR_PHASE.CANCELLED
        );

        (bidAmount, , bidder, isActive) = auctionInstance.bids(bidId2[0]);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            depositorBalance + 32 ether
        );
    }

    function test_CorrectValidatorAttatchedToNft() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 1);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorManagerInstance.registerNodeOperator(proof2, _ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bidId1[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray,
            proof
        );

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](2);
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

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId1, depositDataArray);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bidId2 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );
        uint256[] memory bidIdArray2 = new uint256[](1);
        bidIdArray2[0] = bidId2[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray2,
            proof2
        );

        etherFiNode = managerInstance.etherfiNodeAddress(2);
        root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        depositDataArray[1] = IStakingManager.DepositData({
            publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            depositDataRoot: root,
            ipfsHashForEncryptedValidatorKey: "test_ipfs"
        });

        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId2, depositDataArray);

        assertEq(
            BNFTInstance.ownerOf(bidId1[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TNFTInstance.ownerOf(bidId1[0]),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            BNFTInstance.ownerOf(bidId2[0]),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TNFTInstance.ownerOf(bidId2[0]),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            BNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            1
        );
        assertEq(
            TNFTInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            1
        );
        assertEq(
            BNFTInstance.balanceOf(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf),
            1
        );
        assertEq(
            TNFTInstance.balanceOf(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf),
            1
        );
    }

    function test_SetMaxDeposit() public {
        assertEq(stakingManagerInstance.maxBatchDepositSize(), 25);
        vm.prank(owner);
        stakingManagerInstance.setMaxBatchDepositSize(12);
        assertEq(stakingManagerInstance.maxBatchDepositSize(), 12);

        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        stakingManagerInstance.setMaxBatchDepositSize(12);
    }

    function test_EventDepositCancelled() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(proof, _ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        hoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId1, proof);

        vm.expectEmit(true, false, false, true);
        vm.prank(alice);
        emit DepositCancelled(bidId1[0]);
        stakingManagerInstance.batchCancelDeposit(bidId1);
    }

    function test_EventValidatorRegistered() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(
            1,
            0.1 ether
        );

        startHoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId1, proof);

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        IStakingManager.DepositData[]
            memory depositDataArray = new IStakingManager.DepositData[](1);
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


        vm.expectEmit(true, true, true, true);
        emit ValidatorRegistered(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, alice, bob, bidId1[0], hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c", "test_ipfs");
        stakingManagerInstance.batchRegisterValidators(_getDepositRoot(), bidId1, alice, bob, depositDataArray);
        assertEq(BNFTInstance.ownerOf(bidId1[0]), alice);
        assertEq(TNFTInstance.ownerOf(bidId1[0]), bob);
    }

    function test_MaxBatchBidGasFee() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.4 ether}(
            4,
            0.1 ether
        );

        startHoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 128 ether}(bidIds, proof);
    }

    function test_CanOnlySetAddressesOnce() public {
        vm.startPrank(owner);
        vm.expectRevert("Address already set");
        stakingManagerInstance.registerEtherFiNodeImplementationContract(
            address(0)
        );

        vm.expectRevert("Address already set");
        stakingManagerInstance.registerTNFTContract(address(0));

        vm.expectRevert("Address already set");
        stakingManagerInstance.registerBNFTContract(address(0));

        vm.expectRevert("Address already set");
        stakingManagerInstance.setLiquidityPoolAddress(address(0));

        vm.expectRevert("Address already set");
        stakingManagerInstance.setEtherFiNodesManagerAddress(address(0));
    }

    function test_EnablingAndDisablingWhitelistingWorks() public {
        assertEq(stakingManagerInstance.whitelistEnabled(), false);

        vm.startPrank(owner);
        stakingManagerInstance.enableWhitelist();
        assertEq(stakingManagerInstance.whitelistEnabled(), true);

        stakingManagerInstance.disableWhitelist();
        assertEq(stakingManagerInstance.whitelistEnabled(), false);
    }
}
