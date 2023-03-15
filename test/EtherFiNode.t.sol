// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/AuctionManager.sol";
import "../src/BNFT.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract EtherFiNodeTest is Test {
    IStakingManager public depositInterface;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    AuctionManager public auctionInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    EtherFiNode public safeInstance;
    EtherFiNodesManager public managerInstance;

    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);

    string _ipfsHash = "ipfsHash";
    string aliceIPFSHash = "AliceIpfsHash";

    uint256[] bidId;

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(
            address(nodeOperatorKeyManagerInstance)
        );
        auctionInstance.updateMerkleRoot(root);
        protocolRevenueManagerInstance = new ProtocolRevenueManager();

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
        auctionInstance.setProtocolRevenueManager(
            address(protocolRevenueManagerInstance)
        );

        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        protocolRevenueManagerInstance.setAuctionManagerAddress(
            address(auctionInstance)
        );
        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );

        test_data = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        test_data_2 = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2",
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash_2"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.createBidWhitelisted{value: 0.1 ether}(
            proof,
            1,
            0.1 ether
        );

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);

        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId[0]);
        safeInstance = EtherFiNode(payable(etherFiNode));

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
    }

    function test_WithdrawFundsFailsIfNotCorrectCaller() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(safeInstance).call{value: 0.04 ether}("");
        require(sent, "Failed to send Ether");

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Incorrect caller");
        managerInstance.withdrawFunds(0);
    }

    function test_EtherFiNodeMultipleSafesWorkCorrectly() public {
        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.05 ether + 1
        );

        bytes32[] memory proofAlice = merkle.getProof(whiteListedAddresses, 3);
        bytes32[] memory proofChad = merkle.getProof(whiteListedAddresses, 4);

        vm.prank(alice);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        vm.prank(chad);
        nodeOperatorKeyManagerInstance.registerNodeOperator(aliceIPFSHash, 5);

        hoax(alice);
        uint256[] memory bidId1 = auctionInstance.createBidWhitelisted{
            value: 0.4 ether
        }(proofAlice, 1, 0.4 ether);

        hoax(chad);
        uint256[] memory bidId2 = auctionInstance.createBidWhitelisted{
            value: 0.3 ether
        }(proofChad, 1, 0.3 ether);

        hoax(bob);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        hoax(dan);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        {
            address staker_2 = stakingManagerInstance
                .bidIdToStaker(bidId1[0]);
            address staker_3 = stakingManagerInstance
                .bidIdToStaker(bidId2[0]);
            assertEq(staker_2, bob);
            assertEq(staker_3, dan);
        }

        startHoax(bob);
        stakingManagerInstance.registerValidator(bidId1[0], test_data_2);
        vm.stopPrank();

        assertEq(
            protocolRevenueManagerInstance.globalRevenueIndex(),
            0.15 ether + 1
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(1),
            0.15 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId1[0]
            ),
            0.1 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId2[0]
            ),
            0
        );
        assertEq(address(managerInstance.getEtherFiNodeAddress(bidId1[0])).balance, 0.2 ether);

        startHoax(dan);
        stakingManagerInstance.registerValidator(bidId2[0], test_data_2);
        vm.stopPrank();

        assertEq(address(managerInstance.getEtherFiNodeAddress(bidId2[0])).balance, 0.15 ether);
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(1),
            0.2 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId1[0]
            ),
            0.15 ether
        );
        assertEq(
            protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(
                bidId2[0]
            ),
            0.05 ether
        );
    }

    function test_SendExitRequestWorksCorrectly() public {
        assertEq(managerInstance.isExitRequested(bidId[0]), false);

        hoax(alice);
        vm.expectRevert("You are not the owner of the T-NFT");
        managerInstance.sendExitRequest(bidId[0]);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        managerInstance.sendExitRequest(bidId[0]);        

        assertEq(managerInstance.isExitRequested(bidId[0]), true);

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        vm.expectRevert("Exit request was already sent.");
        managerInstance.sendExitRequest(bidId[0]);      

        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0);  

        // 1 day passed
        vm.warp(1 + 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.03 ether);  

        vm.warp(1 + 86400 + 3600);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.03 ether);  

        vm.warp(1 + 2 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.0591 ether);  

        // 10 days passed
        vm.warp(1 + 10 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.262575873105071740 ether);  

        // 28 days passed
        vm.warp(1 + 28 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.573804794831376551 ether);  

        // 365 days passed
        vm.warp(1 + 365 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 0.999985151485507863 ether);

        // more than 1 year passed
        vm.warp(1 + 366 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);

        vm.warp(1 + 400 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);

        vm.warp(1 + 1000 * 86400);
        assertEq(managerInstance.getNonExitPenaltyAmount(bidId[0]), 1 ether);
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
        whiteListedAddresses.push(keccak256(abi.encodePacked(chad)));

        root = merkle.getRoot(whiteListedAddresses);
    }
}
