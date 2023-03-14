// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/StakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/NodeOperatorKeyManager.sol";
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
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
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

    string aliceIPFSHash = "AliceIPFS";
    string _ipfsHash = "ipfsHash";

    function setUp() public {
        vm.startPrank(owner);

        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        treasuryInstance.setAuctionManagerContractAddress(
            address(auctionInstance)
        );
        auctionInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        auctionInstance.setEtherFiNodesManagerAddress(address(managerInstance));
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
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 10);

        vm.prank(bob);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 10);

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 10);

        // Alice Bids
        hoax(alice);
        uint256[] memory aliceBidIds = auctionInstance.createBid{
            value: 0.6 ether
        }(proof, 6, 0.1 ether);

        // Bob Bids
        hoax(bob);
        uint256[] memory bobBidIds = auctionInstance.createBid{value: 3 ether}(
            proof,
            3,
            1 ether
        );

        // Chad Bids
        hoax(chad);
        uint256[] memory chadBidIds = auctionInstance.createBid{value: 1 ether}(
            proof,
            5,
            0.2 ether
        );

        assertEq(aliceBidIds.length, 6);
        assertEq(bobBidIds.length, 3);
        assertEq(chadBidIds.length, 5);

        // Bob has highest bid
        assertEq(auctionInstance.currentHighestBidId(), bobBidIds[0]);
        assertEq(auctionInstance.getNumberOfActivebids(), 14);

        // Dan stakes
        startHoax(dan);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        (, , , , , bool isBobBid1Active) = auctionInstance.bids(bobBidIds[0]);
        (, , , , , bool isBobBid2Active) = auctionInstance.bids(bobBidIds[1]);
        (, , , , , bool isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's first bid
        address staker = stakingManagerInstance.getStakerRelatedToValidator(
            bobBidIds[0]
        );

        assertEq(auctionInstance.getNumberOfActivebids(), 13);

        // Bob's second bid is now highest
        assertEq(auctionInstance.currentHighestBidId(), bobBidIds[1]);

        assertFalse(isBobBid1Active);
        assertTrue(isBobBid2Active);
        assertTrue(isBobBid3Active);

        assertEq(staker, dan);
        vm.stopPrank();

        // Egg stakes
        startHoax(egg);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        (, , , , , isBobBid2Active) = auctionInstance.bids(bobBidIds[1]);
        (, , , , , isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's second bid
        staker = stakingManagerInstance.getStakerRelatedToValidator(
            bobBidIds[1]
        );

        assertEq(auctionInstance.getNumberOfActivebids(), 12);

        // Bob's thrid bid is now highest
        assertEq(auctionInstance.currentHighestBidId(), bobBidIds[2]);

        assertFalse(isBobBid1Active);
        assertFalse(isBobBid2Active);
        assertTrue(isBobBid3Active);

        assertEq(staker, egg);
        vm.stopPrank();

        // Greg stakes
        startHoax(greg);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        (, , , , , isBobBid3Active) = auctionInstance.bids(bobBidIds[2]);

        // Matches with Bob's third bid
        staker = stakingManagerInstance.getStakerRelatedToValidator(
            bobBidIds[2]
        );

        assertEq(auctionInstance.getNumberOfActivebids(), 11);

        // Chad's first bid is now highest
        assertEq(auctionInstance.currentHighestBidId(), chadBidIds[0]);

        assertFalse(isBobBid3Active);

        assertEq(staker, greg);
        vm.stopPrank();

        // Henry stakes
        startHoax(henry);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        (, , , , , bool isChadBid1Active) = auctionInstance.bids(chadBidIds[0]);
        (, , , , , bool isChadBid2Active) = auctionInstance.bids(chadBidIds[1]);
        (, , , , , bool isChadBid3Active) = auctionInstance.bids(chadBidIds[2]);
        (, , , , , bool isChadBid4Active) = auctionInstance.bids(chadBidIds[3]);
        (, , , , , bool isChadBid5Active) = auctionInstance.bids(chadBidIds[4]);

        // Matches with Chad's first bid
        staker = stakingManagerInstance.getStakerRelatedToValidator(
            chadBidIds[0]
        );

        assertEq(auctionInstance.getNumberOfActivebids(), 10);

        // Chad's second bid is now highest
        assertEq(auctionInstance.currentHighestBidId(), chadBidIds[1]);

        assertFalse(isChadBid1Active);
        assertTrue(isChadBid2Active);
        assertTrue(isChadBid3Active);
        assertTrue(isChadBid4Active);
        assertTrue(isChadBid5Active);

        assertEq(staker, henry);
        vm.stopPrank();
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

//         ) = auctionInstance.bids(auctionInstance.currentHighestBidId());

//         assertEq(auctionInstance.numberOfBids() - 1, 1);
//         assertEq(amount, 0.3 ether);
//         assertEq(bidderAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         assertEq(auctionInstance.currentHighestBidId(), 1);
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
