// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorKeyManager.sol";
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
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
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

    string _ipfsHash = "IPFSHash";

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
        auctionInstance.setProtocolRevenueManager(address(protocolRevenueManagerInstance));

        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        protocolRevenueManagerInstance.setAuctionManagerAddress(address(auctionInstance));
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

        vm.startPrank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);
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

    function test_AddAuctionRevenueWorksAndFailsCorrectly() public {
        // 1
        hoax(address(auctionInstance));
        vm.expectRevert("Incorrect amount");
        protocolRevenueManagerInstance.addAuctionRevenue{value: 0}(1, 1 ether);

        // 2
        hoax(address(auctionInstance));
        vm.expectRevert("No Active Validator");
        protocolRevenueManagerInstance.addAuctionRevenue{value: 1 ether}(1, 1 ether);

        address nodeOperator = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931;
        startHoax(nodeOperator);
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);
        vm.stopPrank();

        assertEq(protocolRevenueManagerInstance.getGlobalRevenueIndex(), 1);
        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        startHoax(alice);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        assertEq(address(protocolRevenueManagerInstance).balance, 0);

        stakingManagerInstance.registerValidator(bidId, test_data);
        vm.stopPrank();

        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId);

        assertEq(address(protocolRevenueManagerInstance).balance, 0.1 ether);
        assertEq(protocolRevenueManagerInstance.getAccruedRewards(bidId), 0.1 ether);
        assertEq(protocolRevenueManagerInstance.getGlobalRevenueIndex(), 0.1 ether + 1);

        // 3
        hoax(address(auctionInstance));
        vm.expectRevert("auctionFeeTransfer is already processed for the validator.");
        protocolRevenueManagerInstance.addAuctionRevenue{value: 1 ether}(bidId, 1 ether);

        assertEq(address(protocolRevenueManagerInstance).balance, 0.1 ether);
        assertEq(address(etherFiNode).balance, 0);
        protocolRevenueManagerInstance.distributeAuctionRevenue(bidId);
        assertEq(address(protocolRevenueManagerInstance).balance, 0);
        assertEq(address(etherFiNode).balance, 0.1 ether);

        protocolRevenueManagerInstance.distributeAuctionRevenue(bidId);
        assertEq(address(protocolRevenueManagerInstance).balance, 0);
        assertEq(address(etherFiNode).balance, 0.1 ether);
    }

    function test_modifiers() public {
        hoax(alice);
        vm.expectRevert("Only auction manager function");
        protocolRevenueManagerInstance.addAuctionRevenue(0, 0);

        vm.expectRevert("Only owner function");
        protocolRevenueManagerInstance.setAuctionManagerAddress(alice);

        vm.expectRevert("Only owner function");
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(alice);
    }
    
}
