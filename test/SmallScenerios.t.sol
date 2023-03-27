// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/StakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract AuctionManagerTest is Test {
    StakingManager public stakingManagerInstance;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);
    address egg = vm.addr(6);
    address greg = vm.addr(7);
    address henry = vm.addr(8);

    bytes aliceIPFSHash = "AliceIPFS";
    bytes _ipfsHash = "ipfsHash";
    bytes32 salt = 0x1234567890123456789012345678901234567890123456789012345678901234;

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorManagerInstance = new NodeOperatorManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorManagerInstance)
        );
        nodeOperatorManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        protocolRevenueManagerInstance = new ProtocolRevenueManager{salt:salt}();
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        test_data = IStakingManager.DepositData({
            publicKey: "test_pubkey",
            signature: "test_signature",
            depositDataRoot: "test_deposit_root",
            ipfsHashForEncryptedValidatorKey: "test_ipfsHash"
        });

        vm.stopPrank();
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)
            )
        );

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(bob)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(chad)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(dan)));

        root = merkle.getRoot(whiteListedAddresses);
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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
        startHoax(egg);
        uint256[] memory bidIdArray1 = new uint256[](1);
        bidIdArray1[0] = bobBidIds[1];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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

        assertEq(staker, egg);
        vm.stopPrank();

        // Greg stakes
        startHoax(greg);
        uint256[] memory bidIdArray2 = new uint256[](1);
        bidIdArray2[0] = bobBidIds[2];

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
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
}

//     /**
//      *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//      *  One deposit - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
//      */
//     function test_ScenarioOne() public {
//         bytes32[] memory proofForAddress1 = merkle.getProof(
//             whiteListedAddresses,
//             0
//         );

//         startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.3 ether}(
//             proofForAddress1,
//             "test_pubKey"
//         );
//         assertEq(auctionInstance.numberOfActiveBids(), 1);

//         assertEq(address(auctionInstance).balance, 0.3 ether);
//         assertEq(address(stakingManagerInstance).balance, 0);

//         (
//             uint256 amount,
//             ,
//             address bidderAddress,
//             bool isActiveBeforeStake,

//         assertEq(auctionInstance.numberOfBids() - 1, 1);
//         assertEq(amount, 0.3 ether);
//         assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         assertEq(isActiveBeforeStake, true);

//         vm.stopPrank();
//         startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

//         stakingManagerInstance.deposit{value: 0.032 ether}();
//         // (, address withdrawalSafe, , , , , , ) = stakingManagerInstance.stakes(0);

//         assertEq(address(stakingManagerInstance).balance, 0.032 ether);
//         assertEq(address(auctionInstance).balance, 0.3 ether);
//         // assertEq(withdrawalSafe.balance, 0.3 ether);

//         (, , , bool isActiveAfterStake, ) = auctionInstance.bids(1);
//         assertEq(isActiveAfterStake, false);
//     }

//     /**
//      *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//      *  One cancel - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//      *  Second bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
//      *  One updated bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
//      */
//     function test_ScenarioTwo() public {
//         bytes32[] memory proofForAddress1 = merkle.getProof(
//             whiteListedAddresses,
//             0
//         );
//         bytes32[] memory proofForAddress2 = merkle.getProof(
//             whiteListedAddresses,
//             1
//         );

//         startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.3 ether}(
//             proofForAddress1,
//             "test_pubKey"
//         );
//         assertEq(auctionInstance.numberOfActiveBids(), 1);

//         assertEq(address(auctionInstance).balance, 0.3 ether);

//         (
//             uint256 amount,
//             ,
//             address bidderAddress,
//             bool isActiveAfterStake,

//         ) = auctionInstance.bids(auctionInstance.currentHighestBidId());

//         assertEq(auctionInstance.numberOfBids() - 1, 1);
//         assertEq(amount, 0.3 ether);
//         assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         assertEq(auctionInstance.currentHighestBidId(), 1);
//         assertEq(isActiveAfterStake, true);

//         auctionInstance.cancelBid(1);
//         assertEq(auctionInstance.numberOfActiveBids(), 0);

//         (, , , bool isActiveAfterCancel, ) = auctionInstance.bids(1);
//         assertEq(isActiveAfterCancel, false);

//         vm.stopPrank();
//         startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);

//         auctionInstance.bidOnStake{value: 0.2 ether}(
//             proofForAddress2,
//             "test_pubKey"
//         );
//         assertEq(auctionInstance.numberOfBids() - 1, 2);
//         assertEq(auctionInstance.currentHighestBidId(), 2);
//         assertEq(address(auctionInstance).balance, 0.2 ether);
//         assertEq(auctionInstance.numberOfActiveBids(), 1);

//         // auctionInstance.increaseBid{value: 0.3 ether}(2);
//         // assertEq(auctionInstance.numberOfBids() - 1, 2);
//         // assertEq(auctionInstance.currentHighestBidId(), 2);
//         // assertEq(address(auctionInstance).balance, 0.5 ether);
//         // assertEq(auctionInstance.numberOfActiveBids(), 1);
//     }

//     function test_TwoStakingManagersAtOnceStillWorks() public {
//         bytes32[] memory proofForAddress1 = merkle.getProof(
//             whiteListedAddresses,
//             0
//         );
//         bytes32[] memory proofForAddress2 = merkle.getProof(
//             whiteListedAddresses,
//             1
//         );
//         bytes32[] memory proofForAddress3 = merkle.getProof(
//             whiteListedAddresses,
//             2
//         );

//         //Bid One
//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.1 ether}(
//             proofForAddress1,
//             "test_pubKey"
//         );

//         //Bid Two
//         hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
//         auctionInstance.bidOnStake{value: 0.3 ether}(
//             proofForAddress2,
//             "test_pubKey"
//         );

//         //Bid Three
//         hoax(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20);
//         auctionInstance.bidOnStake{value: 0.2 ether}(
//             proofForAddress3,
//             "test_pubKey"
//         );

//         assertEq(auctionInstance.currentHighestBidId(), 2);

//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         stakingManagerInstance.deposit{value: 0.032 ether}();
//         assertEq(auctionInstance.currentHighestBidId(), 3);
//         hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
//         stakingManagerInstance.deposit{value: 0.032 ether}();
//         assertEq(auctionInstance.currentHighestBidId(), 1);
//         assertEq(address(stakingManagerInstance).balance, 0.064 ether);
//     }

//     /**
//      *  One bid - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//      *  Second bid - 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
//      *  One deposit - 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//      *  Register validator - 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//      *  Accept validator - 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
//      */
//     function test_ScenarioThree() public {
//         bytes32[] memory proofForAddress1 = merkle.getProof(
//             whiteListedAddresses,
//             0
//         );
//         bytes32[] memory proofForAddress2 = merkle.getProof(
//             whiteListedAddresses,
//             1
//         );
//         bytes32[] memory proofForAddress3 = merkle.getProof(
//             whiteListedAddresses,
//             2
//         );

//         //Bid One
//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         auctionInstance.bidOnStake{value: 0.9 ether}(
//             proofForAddress1,
//             "test_pubKey"
//         );
//         assertEq(address(stakingManagerInstance).balance, 0 ether);
//         assertEq(address(auctionInstance).balance, 0.9 ether);

//         //Bid Two
//         hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
//         auctionInstance.bidOnStake{value: 0.3 ether}(
//             proofForAddress2,
//             "test_pubKey"
//         );
//         assertEq(address(stakingManagerInstance).balance, 0 ether);
//         assertEq(address(auctionInstance).balance, 1.2 ether);

//         //StakingManager One
//         startHoax(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20);
//         stakingManagerInstance.deposit{value: 0.032 ether}();
//         assertEq(address(stakingManagerInstance).balance, 0.032 ether);
//         assertEq(address(auctionInstance).balance, 1.2 ether);

//         //Register validator
//         stakingManagerInstance.registerValidator(
//             0,
//             "Encrypted_Key",
//             "encrypted_key_password",
//             "test_stakerPubKey",
//             test_data
//         );
//         (
//             uint256 validatorId,
//             uint256 bidId,
//             uint256 stakeId,
//             bytes memory validatorKey,
//             bytes memory encryptedValidatorKeyPassword,

//         ) = stakingManagerInstance.validators(0);
//         assertEq(validatorId, 0);
//         assertEq(bidId, 1);
//         assertEq(stakeId, 0);
//         assertEq(validatorKey, "Encrypted_Key");
//         assertEq(encryptedValidatorKeyPassword, "encrypted_key_password");

//         //Accept validator
//         vm.stopPrank();
//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         stakingManagerInstance.acceptValidator(0);

//         assertEq(
//             TestBNFTInstance.ownerOf(0),
//             0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//         );
//         assertEq(
//             TestTNFTInstance.ownerOf(0),
//             0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//         );
//         assertEq(
//             TestBNFTInstance.balanceOf(
//                 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//             ),
//             1
//         );
//         assertEq(
//             TestTNFTInstance.balanceOf(
//                 0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20
//             ),
//             1
//         );
//     }

//     function _merkleSetup() internal {
//         merkle = new Merkle();

//         whiteListedAddresses.push(
//             keccak256(
//                 abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
//             )
//         );
//         whiteListedAddresses.push(
//             keccak256(
//                 abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)
//             )
//         );
//         whiteListedAddresses.push(
//             keccak256(
//                 abi.encodePacked(0x2DEFD6537cF45E040639AdA147Ac3377c7C61F20)
//             )
//         );
//         root = merkle.getRoot(whiteListedAddresses);
//     }
// }
