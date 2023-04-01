pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract TestSetup is Test {

    StakingManager public stakingManagerInstance;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    AuctionManager public auctionInstance;
    Treasury public treasuryInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
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
    address egg = vm.addr(6);
    address greg = vm.addr(7);
    address henry = vm.addr(8);
    address liquidityPool = vm.addr(9);

    bytes aliceIPFSHash = "AliceIPFS";
    bytes _ipfsHash = "ipfsHash";

    function setUpTests() public {
        vm.startPrank(owner);

        // Deploy Contracts
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorManagerInstance = new NodeOperatorManager();
        auctionInstance = new AuctionManager();
        auctionInstance.initialize(address(nodeOperatorManagerInstance));
        nodeOperatorManagerInstance.setAuctionContractAddress(
            address(auctionInstance)
        );
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager();
        stakingManagerInstance.initialize(address(auctionInstance));
        protocolRevenueManagerInstance = new ProtocolRevenueManager();
        protocolRevenueManagerInstance.initialize();

        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInterfaceInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInterfaceInstance()));
        managerInstance = new EtherFiNodesManager();
        managerInstance.initialize(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(protocolRevenueManagerInstance)
        );
        EtherFiNode etherFiNode = new EtherFiNode();

        // Setup dependencies
        nodeOperatorManagerInstance.setAuctionContractAddress(address(auctionInstance));
        nodeOperatorManagerInstance.updateMerkleRoot(root);
        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));
        auctionInstance.setProtocolRevenueManager(address(protocolRevenueManagerInstance));
        protocolRevenueManagerInstance.setAuctionManagerAddress(address(auctionInstance));
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.registerEtherFiNodeImplementationContract(address(etherFiNode));

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

        root = merkle.getRoot(whiteListedAddresses);
    }
}