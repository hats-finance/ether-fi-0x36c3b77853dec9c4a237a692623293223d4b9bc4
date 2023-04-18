// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract SmallScenariosTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    /*------ SCENARIO 1 ------*/
    // 3 Bidders:
    //  Alice - 6 bids of 0.1 ETH
    //  Bob - 3 bids of 1 ETH
    //  Chad - 5 bids of 0.2 ETH

    // 4 Stakers
    //  Dan - Stakes once, should be matched with Bob's first bid of 1 ETH
    //  Egg - Stakes once, should be matched with Bob's second bid of 1 ETH
    //  Greg - Stakes once, should be matched with Bob's third bid of 1 ETH
    //  Henry - Stakes once, should be matched with Chad's first bid of 0.2 ETH
    function test_ScenarioOne() public {
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);
        bytes32[] memory chadProof = merkle.getProof(whiteListedAddresses, 5);

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            10
        );

        vm.prank(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            _ipfsHash,
            10
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            chadProof,
            _ipfsHash,
            10
        );

        // Alice Bids
        hoax(alice);
        uint256[] memory aliceBidIds = auctionInstance.createBid{
            value: 0.6 ether
        }(6, 0.1 ether);

        // Bob Bids
        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{value: 3 ether}(
            3,
            1 ether
        );

        // Chad Bids
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{value: 1 ether}(
            5,
            0.2 ether
        );

        assertEq(aliceBidIds.length, 6);
        assertEq(bobBidIds.length, 3);
        assertEq(chadBidIds.length, 5);

        // Bob has highest bid
        assertEq(auctionInstance.numberOfActiveBids(), 14);

        // Dan stakes
        startHoax(dan);
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = bobBidIds[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray
        );

        (, , , bool isBobBid1Active) = auctionInstance.bids(bobBidIds[0]);
        (, , , bool isBobBid2Active) = auctionInstance.bids(bobBidIds[1]);
        (, , , bool isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's first bid
        address staker = stakingManagerInstance.bidIdToStaker(bobBidIds[0]);

        assertEq(auctionInstance.numberOfActiveBids(), 13);

        // Bob's second bid is now highest

        assertFalse(isBobBid1Active);
        assertTrue(isBobBid2Active);
        assertTrue(isBobBid3Active);

        assertEq(staker, dan);
        vm.stopPrank();

        // Egg stakes
        startHoax(elvis);
        uint256[] memory bidIdArray1 = new uint256[](1);
        bidIdArray1[0] = bobBidIds[1];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray1
        );

        (, , , isBobBid2Active) = auctionInstance.bids(bobBidIds[1]);
        (, , , isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's second bid
        staker = stakingManagerInstance.bidIdToStaker(bobBidIds[1]);

        assertEq(auctionInstance.numberOfActiveBids(), 12);

        assertFalse(isBobBid1Active);
        assertFalse(isBobBid2Active);
        assertTrue(isBobBid3Active);

        assertEq(staker, elvis);
        vm.stopPrank();

        // Greg stakes
        startHoax(greg);
        uint256[] memory bidIdArray2 = new uint256[](1);
        bidIdArray2[0] = bobBidIds[2];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray2
        );

        (, , , isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's third bid
        staker = stakingManagerInstance.bidIdToStaker(bobBidIds[2]);

        assertEq(auctionInstance.numberOfActiveBids(), 11);

        // Chad's first bid is now highest

        assertFalse(isBobBid3Active);

        assertEq(staker, greg);
        vm.stopPrank();

        // Henry stakes
        startHoax(henry);
        uint256[] memory bidIdArray3 = new uint256[](1);
        bidIdArray3[0] = chadBidIds[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray3
        );

        (, , , bool isChadBid1Active) = auctionInstance.bids(chadBidIds[0]);
        (, , , bool isChadBid2Active) = auctionInstance.bids(chadBidIds[1]);
        (, , , bool isChadBid3Active) = auctionInstance.bids(chadBidIds[2]);
        (, , , bool isChadBid4Active) = auctionInstance.bids(chadBidIds[3]);
        (, , , bool isChadBid5Active) = auctionInstance.bids(chadBidIds[4]);

        // Matches with Chad's first bid
        staker = stakingManagerInstance.bidIdToStaker(chadBidIds[0]);

        assertEq(auctionInstance.numberOfActiveBids(), 10);

        assertFalse(isChadBid1Active);
        assertTrue(isChadBid2Active);
        assertTrue(isChadBid3Active);
        assertTrue(isChadBid4Active);
        assertTrue(isChadBid5Active);

        assertEq(staker, henry);
        vm.stopPrank();
    }

    /*------ SCENARIO 2 ------*/

    // Chad - Bids first with 5 bids of 0.2 ETH
    // Dan -  Then stakes once, should be matched with Chad's first bid of 0.2 ETH

    //  Bob - Bids second with 3 bids of 1 ETH after Dan has staked
    //  Greg - The stakes once, should be matched with Bob's first bid of 1 ETH
    function test_ScenarioTwo() public {
        bytes32[] memory chadProof = merkle.getProof(whiteListedAddresses, 5);
        bytes32[] memory bobProof = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(bob);
        nodeOperatorManagerInstance.registerNodeOperator(
            bobProof,
            _ipfsHash,
            10
        );

        vm.prank(chad);
        nodeOperatorManagerInstance.registerNodeOperator(
            chadProof,
            _ipfsHash,
            10
        );

        // Chad Bids
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{value: 1 ether}(
            5,
            0.2 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 5);

        // Dan stakes
        startHoax(dan);
        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = chadBidIds[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray
        );

        assertEq(auctionInstance.numberOfActiveBids(), 4);

        address staker = stakingManagerInstance.bidIdToStaker(chadBidIds[0]);

        assertEq(staker, dan);

        vm.stopPrank();

        // Bob Bids
        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{value: 3 ether}(
            3,
            1 ether
        );

        assertEq(auctionInstance.numberOfActiveBids(), 7);

        // Greg stakes
        startHoax(greg);
        uint256[] memory bidIdArray2 = new uint256[](1);
        bidIdArray2[0] = bobBidIds[0];

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray2
        );

        assertEq(auctionInstance.numberOfActiveBids(), 6);

        staker = stakingManagerInstance.bidIdToStaker(bobBidIds[0]);

        vm.stopPrank();

        assertEq(staker, greg);

        (, , , bool isBobBid1Active) = auctionInstance.bids(bobBidIds[0]);
        (, , , bool isBobBid2Active) = auctionInstance.bids(bobBidIds[1]);
        (, , , bool isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        (, , , bool isChadBid1Active) = auctionInstance.bids(chadBidIds[0]);
        (, , , bool isChadBid2Active) = auctionInstance.bids(chadBidIds[1]);
        (, , , bool isChadBid3Active) = auctionInstance.bids(chadBidIds[2]);
        (, , , bool isChadBid4Active) = auctionInstance.bids(chadBidIds[3]);
        (, , , bool isChadBid5Active) = auctionInstance.bids(chadBidIds[4]);

        // Chad has 4 active bids left
        assertFalse(isChadBid1Active);
        assertTrue(isChadBid2Active);
        assertTrue(isChadBid3Active);
        assertTrue(isChadBid4Active);
        assertTrue(isChadBid5Active);

        // Bob has 2 active bids left
        assertFalse(isBobBid1Active);
        assertTrue(isBobBid2Active);
        assertTrue(isBobBid3Active);
    }

    /**
     *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     *  Second bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
     *  One deposit - 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
     *  Register validator - 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
     *  Accept validator - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
     */
    function test_ScenarioThree() public {
        bytes32[] memory proofForAddress1 = merkle.getProof(
            whiteListedAddresses,
            0
        );
        bytes32[] memory proofForAddress2 = merkle.getProof(
            whiteListedAddresses,
            1
        );
        bytes32[] memory proofForAddress3 = merkle.getProof(
            whiteListedAddresses,
            2
        );

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofForAddress1,
            _ipfsHash,
            10
        );

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorManagerInstance.registerNodeOperator(
            proofForAddress2,
            _ipfsHash,
            10
        );

        //Bid One
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidIds1 = auctionInstance.createBid{value: 0.9 ether}(1, 0.9 ether);
        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0.9 ether);

        //Bid Two
        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256[] memory bidIds2 = auctionInstance.createBid{value: 0.3 ether}(1, 0.3 ether);
        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 1.2 ether);

        //StakingManager One
        startHoax(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidIds1);
        assertEq(address(stakingManagerInstance).balance, 32 ether);
        assertEq(address(auctionInstance).balance, 1.2 ether);

        address etherFiNode = managerInstance.etherfiNodeAddress(bidIds1[0]);
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

        //Register validator
        stakingManagerInstance.registerValidator(_getDepositRoot(), bidIds1[0], depositData);

        assertEq(
            TNFTInstance.ownerOf(bidIds1[0]),
            0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
        );
        assertEq(
            BNFTInstance.ownerOf(bidIds1[0]),
            0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
        );
        assertEq(
            BNFTInstance.balanceOf(
                0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
            ),
            1
        );
        assertEq(
            TNFTInstance.balanceOf(
                0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
            ),
            1
        );
    }
}
