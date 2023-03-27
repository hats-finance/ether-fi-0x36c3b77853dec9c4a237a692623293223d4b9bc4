// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract ProtocolRevenueManagerTest is Test {
    IStakingManager public depositInterface;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    bytes _ipfsHash = "IPFSHash";

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
        protocolRevenueManagerInstance = new ProtocolRevenueManager();

        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );
        TestBNFTInstance = BNFT(stakingManagerInstance.bnftContractAddress());
        TestTNFTInstance = TNFT(stakingManagerInstance.tnftContractAddress());
        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );

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
            ipfsHashForEncryptedValidatorKey: "test_IPFS_hash"
        });

        test_data_2 = IStakingManager.DepositData({
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2",
            ipfsHashForEncryptedValidatorKey: "test_IPFS_hash_2"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory aliceProof = merkle.getProof(whiteListedAddresses, 3);
        vm.startPrank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );
        vm.stopPrank();

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            aliceProof,
            _ipfsHash,
            5
        );
    }

    function test_Receive() public {
        vm.expectRevert("No Active Validator");
        startHoax(alice);
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(1, 1 ether);

        vm.expectRevert("No Active Validator");
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(bidIds);

        vm.expectRevert("No Active Validator");
        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);

        stakingManagerInstance.registerValidator(bidIds[0], test_data);

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 500000000000000001);

        address(protocolRevenueManagerInstance).call{value: 1 ether}("");

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1500000000000000001);
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidId
        );

        stakingManagerInstance.registerValidator(bidId[0], test_data);

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1750000000000000001);

        address(protocolRevenueManagerInstance).call{value: 1 ether}("");
        vm.stopPrank();

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 2250000000000000001);

    }

    function test_GetAccruedAuctionRevenueRewards() public {
        startHoax(alice);

        uint256[] memory bidId = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidId
        );
        stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        assertEq(protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(bidId[0]), 0.5 ether);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256[] memory bidIds2 = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIds2
        );
        stakingManagerInstance.registerValidator(bidIds2[0], test_data);
        vm.stopPrank();

        assertEq(protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(bidId[0]), 0.75 ether);
        assertEq(protocolRevenueManagerInstance.getAccruedAuctionRevenueRewards(bidIds2[0]), 0.25 ether);
    }

    function test_AddAuctionRevenueWorksAndFailsCorrectly() public {
        // 1
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

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );
        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        stakingManagerInstance.registerValidator(bidId[0], test_data);
        vm.stopPrank();

        // 0.1 ether
        //  -> 0.05 ether to its etherfi Node contract
        //  -> 0.05 ether to the protocol revenue manager contract
        address etherFiNode = managerInstance.etherfiNodeAddress(bidId[0]);
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
         whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(alice)
            )
        );

        root = merkle.getRoot(whiteListedAddresses);
    }
}
