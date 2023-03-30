// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/AuctionManager.sol";
import "../src/BNFT.sol";
import "../src/NodeOperatorManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract RewardsSkimmingTest is Test {
    IStakingManager public depositInterface;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    AuctionManager public auctionInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    Treasury public treasuryInstance;
    EtherFiNode public safeInstance;
    EtherFiNodesManager public managerInstance;

    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IStakingManager.DepositData public test_data;

    uint256 num_operators;
    uint256 num_stakers;
    uint256 num_people;
    address[] operators;
    address[] stakers;
    address[] people;
    uint256[] validatorIds;

    uint256[] validatorIdsOfMixedTNftHolders;
    uint256[] validatorIdsOfTNftsInLiquidityPool;

    bytes _ipfsHash = "ipfsHash";
    bytes aliceIPFSHash = "AliceIpfsHash";

    uint256[] bidId;

    address owner = vm.addr(1);
    address liquidityPool = vm.addr(2);

    function setUp() public {
        num_operators = 1; // should be 1
        num_stakers = 32;
        num_people = num_stakers;
        for (uint i = 0; i < num_operators; i++) {
            operators.push(vm.addr(i+1));
            vm.deal(operators[i], 1 ether);
        }
        for (uint i = 0; i < num_stakers; i++) {
            stakers.push(vm.addr(i+10000));
            vm.deal(stakers[i], 1 ether);
        }
        for (uint i = 0; i < num_people; i++) {
            people.push(vm.addr(i+10000000));
            vm.deal(people[i], 1 ether);
        }    

        vm.startPrank(owner);

        // Deploy Contracts
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorManagerInstance = new NodeOperatorManager();
        auctionInstance = new AuctionManager(address(nodeOperatorManagerInstance));
        protocolRevenueManagerInstance = new ProtocolRevenueManager();
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInterfaceInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInterfaceInstance()));
        managerInstance = new EtherFiNodesManager(
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
        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(operators[0]);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            1000
        );
        for (uint i = 0; i < num_stakers; i++) {
            uint256[] memory ids = auctionInstance.createBid{value: 0.4 ether}(1, 0.4 ether);
            validatorIds.push(ids[0]);
            if (i % 2 == 0) {
                validatorIdsOfMixedTNftHolders.push(ids[0]);
            } else {
                validatorIdsOfTNftsInLiquidityPool.push(ids[0]);
            }
        }
        vm.stopPrank();

        for (uint i = 0; i < num_stakers; i++) {
            startHoax(stakers[i]);
            uint256[] memory candidateBidIds = new uint256[](1);
             candidateBidIds[0] = validatorIds[i];
            stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(candidateBidIds);
            stakingManagerInstance.registerValidator(validatorIds[i], test_data);
            vm.stopPrank();
        }

        // Mix the T-NFT holders
        for (uint i = 0; i < num_stakers; i++) {
            vm.startPrank(stakers[i]);
            if (i % 2 == 0) {
                TestTNFTInstance.transferFrom(stakers[i], people[i], validatorIds[i]);
            } else {
                TestTNFTInstance.transferFrom(stakers[i], liquidityPool, validatorIds[i]);
            }
            vm.stopPrank();
        }        
    }

    function _merkleSetup() internal {
        merkle = new Merkle();
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(operators[0])
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(operators[0])
            )
        );
        root = merkle.getRoot(whiteListedAddresses);
    }

    function _deals() internal {
        vm.deal(liquidityPool, 1 ether);
        vm.deal(address(managerInstance), 100 ether);
        vm.deal(operators[0], 1 ether);
        for (uint i = 0; i < num_stakers; i++) {
            vm.deal(payable(managerInstance.etherfiNodeAddress(i)), 1 ether);
            vm.deal(stakers[i], 1 ether);
            vm.deal(people[i], 1 ether);
        }
    }

    function test_partialWithdraw_batch_base() public {
        _deals();
        startHoax(operators[0]);
        for (uint i = 0; i < num_stakers/2; i++) {
            managerInstance.partialWithdraw(validatorIds[i], true, false, false);
        }
        vm.stopPrank();
    }

    function test_partialWithdrawBatchGroupByOperator() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchGroupByOperator(operators[0], validatorIdsOfMixedTNftHolders, true, false, false);
        vm.stopPrank();
    }

    function test_partialWithdrawBatchForTNftInLiquidityPool() public {
        _deals();
        startHoax(operators[0]);
        // managerInstance.partialWithdrawBatchForOperatorAndTNftHolder(operators[0], liquidityPool, validatorIdsOfTNftsInLiquidityPool);
        vm.stopPrank();
    }

}