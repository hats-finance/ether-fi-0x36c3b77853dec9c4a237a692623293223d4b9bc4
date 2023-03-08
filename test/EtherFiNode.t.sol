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

    uint256 bidId;

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new AuctionManager(address(nodeOperatorKeyManagerInstance));
        treasuryInstance.setAuctionManagerContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        stakingManagerInstance = new StakingManager(address(auctionInstance));
        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));
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
        stakingManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));

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

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bidId = auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();
        stakingManagerInstance.registerValidator(bidId, test_data);
        vm.stopPrank();

        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId);
        safeInstance = EtherFiNode(payable(etherFiNode));
    }

    function test_ReceiveAuctionManagerFundsWorksCorrectly() public {
        assertEq(
            managerInstance.withdrawableBalance(
                bidId,
                IEtherFiNodesManager.ValidatorRecipientType.TREASURY
            ),
            10000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                bidId,
                IEtherFiNodesManager.ValidatorRecipientType.OPERATOR
            ),
            10000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                bidId,
                IEtherFiNodesManager.ValidatorRecipientType.BNFTHOLDER
            ),
            20000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                bidId,
                IEtherFiNodesManager.ValidatorRecipientType.TNFTHOLDER
            ),
            60000000000000000
        );
        assertEq(address(safeInstance).balance, 0.1 ether);
        assertEq(address(managerInstance).balance, 0 ether);
    }

    function test_ReceiveAuctionManagerFundsFailsIfNotAuctionManagerContractCalling() public {
        vm.expectRevert("Only auction contract function");
        managerInstance.receiveAuctionFunds(0, 0.1 ether);
    }

    function test_WithdrawFundsFailsIfNotCorrectCaller() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(safeInstance).call{value: 0.04 ether}("");
        require(sent, "Failed to send Ether");

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Incorrect caller");
        managerInstance.withdrawFunds(0);
    }

    function test_WithdrawFundsWorksCorrectly() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(safeInstance).call{value: 0.04 ether}("");
        require(sent, "Failed to send Ether");
        assertEq(address(safeInstance).balance, 0.14 ether);
        assertEq(address(auctionInstance).balance, 0 ether);

        uint256 stakerBalance = 0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            .balance;
        uint256 operatorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        hoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        managerInstance.withdrawFunds(bidId);
        assertEq(address(safeInstance).balance, 0 ether);
        assertEq(address(treasuryInstance).balance, 0.01040 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            operatorBalance + 0.0104 ether
        );
    }

    function test_EtherFiNodeMultipleSafesWorkCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(alice);
        uint256 bidId1 = auctionInstance.bidOnStake{value: 0.4 ether}(proof);

        hoax(chad);
        uint256 bidId2 = auctionInstance.bidOnStake{value: 0.3 ether}(proof);

        hoax(bob);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        hoax(dan);
        stakingManagerInstance.depositForAuction{value: 0.032 ether}();

        {
            address staker_2 = stakingManagerInstance.getStakerRelatedToValidator(bidId1);
            address staker_3 = stakingManagerInstance.getStakerRelatedToValidator(bidId2);            
            assertEq(staker_2, bob);
            assertEq(staker_3, dan);
        }

        address withdrawSafeAddress_2 =  managerInstance.getEtherFiNodeAddress(bidId1);
        address withdrawSafeAddress_3 =  managerInstance.getEtherFiNodeAddress(bidId2);
        
        startHoax(bob);
        stakingManagerInstance.registerValidator(bidId1, test_data_2);
        vm.stopPrank();

        startHoax(dan);
        stakingManagerInstance.registerValidator(bidId2, test_data_2);
        vm.stopPrank();

        assertEq(withdrawSafeAddress_2.balance, 0.4 ether);
        assertEq(withdrawSafeAddress_3.balance, 0.3 ether);

        // Node Operators
        uint256 aliceBalBefore = alice.balance;
        uint256 chadBalBefore = chad.balance;

        //Stakers
        uint256 bobBalBefore = bob.balance;
        uint256 danBalBefore = dan.balance;

        // Treasury
        uint256 treasuryBalBefore = address(treasuryInstance).balance;

        // Simulate withdrawal from beacon chain
        {
            startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
            (bool sent, ) = address(withdrawSafeAddress_2).call{value: 1 ether}("");
            require(sent, "Failed to send Ether");
            (sent, ) = address(withdrawSafeAddress_3).call{value: 10 ether}("");
            require(sent, "Failed to send Ether");
            vm.stopPrank();
        }

        console.log(alice.balance);
        console.log(withdrawSafeAddress_2.balance);


        hoax(bob);
        managerInstance.withdrawFunds(bidId1);
        console.log("Alice balance after withdrawal");
        console.log(alice);

        hoax(dan);
        managerInstance.withdrawFunds(bidId2);

        assertEq(withdrawSafeAddress_2.balance, 0);
        assertEq(withdrawSafeAddress_3.balance, 0);

        // Validator 2 Rewards
        uint256 aliceSplit = managerInstance.withdrawn(
            bidId1,
            IEtherFiNodesManager.ValidatorRecipientType.OPERATOR
        );
        uint256 bobSplit = managerInstance.withdrawn(
            bidId1,
            IEtherFiNodesManager.ValidatorRecipientType.TNFTHOLDER
        ) +
            managerInstance.withdrawn(
                bidId1,
                IEtherFiNodesManager.ValidatorRecipientType.BNFTHOLDER
            );
        uint256 treasurySplit = managerInstance.withdrawn(
            bidId1,
            IEtherFiNodesManager.ValidatorRecipientType.TREASURY
        );

        // Validator 3 rewards
        uint256 chadSplit = managerInstance.withdrawn(
            bidId2,
            IEtherFiNodesManager.ValidatorRecipientType.OPERATOR
        );
        uint256 danSplit = managerInstance.withdrawn(
            bidId2,
            IEtherFiNodesManager.ValidatorRecipientType.TNFTHOLDER
        ) +
            managerInstance.withdrawn(
                bidId2,
                IEtherFiNodesManager.ValidatorRecipientType.BNFTHOLDER
            );
        treasurySplit += managerInstance.withdrawn(
            bidId2,
            IEtherFiNodesManager.ValidatorRecipientType.TREASURY
        );


        assertEq(alice.balance, aliceBalBefore + aliceSplit);
        assertEq(chad.balance, chadBalBefore + chadSplit);

        assertEq(bob.balance, bobBalBefore + bobSplit);
        assertEq(dan.balance, danBalBefore + danSplit);

        assertEq(
            address(treasuryInstance).balance,
            treasuryBalBefore + treasurySplit
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
