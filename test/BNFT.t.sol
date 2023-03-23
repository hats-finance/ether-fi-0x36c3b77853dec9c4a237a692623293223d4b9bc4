// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/StakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/ProtocolRevenueManager.sol";

import "../src/BNFT.sol";
import "../src/NodeOperatorManager.sol";
import "../src/TNFT.sol";
import "../src/AuctionManager.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract BNFTTest is Test {
    StakingManager public stakingManagerInstance;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;
    IStakingManager.DepositData public test_data;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    bytes _ipfsHash = "ipfs";

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
        protocolRevenueManagerInstance = new ProtocolRevenueManager();
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
            ipfsHashForEncryptedValidatorKey: "test_ipfs_hash"
        });

        vm.stopPrank();
    }

    function test_Mint() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );
        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        vm.stopPrank();

        hoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIds
        );

        startHoax(alice);
        stakingManagerInstance.registerValidator(bidIds[0], test_data);
        vm.stopPrank();

        assertEq(TestBNFTInstance.ownerOf(1), alice);
        assertEq(TestBNFTInstance.balanceOf(alice), 1);
    }

    function test_BNFTContractGetsInstantiatedCorrectly() public {
        assertEq(
            TestBNFTInstance.stakingManagerContractAddress(),
            address(stakingManagerInstance)
        );
        assertEq(TestBNFTInstance.nftValue(), 0.002 ether);
    }

    function test_BNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only deposit contract function");
        TestBNFTInstance.mint(address(alice), 1);
    }

    function test_BNFTCannotBeTransferred() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIdArray
        );

        vm.expectRevert("Err: token is SOUL BOUND");
        TestBNFTInstance.transferFrom(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            address(alice),
            0
        );
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
}
