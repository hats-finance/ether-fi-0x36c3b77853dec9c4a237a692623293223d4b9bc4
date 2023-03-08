// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IStakingManager.sol";
import "src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/AuctionManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract StakingManagerTest is Test {
    IStakingManager public depositInterface;
    EtherFiNode public withdrawSafeInstance;
    EtherFiNodesManager public managerInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    StakingManager public stakingManagerInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
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

        stakingManagerInstance = new StakingManager(address(auctionInstance));
        stakingManagerInstance.setTreasuryAddress(address(treasuryInstance));

        auctionInstance.setStakingManagerContractAddress(
            address(stakingManagerInstance)
        );

        TestBNFTInstance = BNFT(address(stakingManagerInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(stakingManagerInstance.TNFTInstance()));

        managerInstance = new EtherFiNodesManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TestBNFTInstance),
            address(TestTNFTInstance)
        );

        stakingManagerInstance.setEtherFiNodesManagerAddress(
            address(managerInstance)
        );
        auctionInstance.setEtherFiNodesManagerAddress(address(managerInstance));

        test_data = IStakingManager.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        test_data_2 = IStakingManager.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials_2",
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2"
        });

        vm.stopPrank();
    }

    function test_StakingManagerSwitchWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        assertTrue(stakingManagerInstance.test());
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);

        stakingManagerInstance.switchMode();
        console.logBool(stakingManagerInstance.test());

        vm.prank(owner);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(owner);
        auctionInstance.createBid{value: 0.1 ether}(proof);

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.deposit{value: 0.032 ether}(0);

        stakingManagerInstance.switchMode();
        console.logBool(stakingManagerInstance.test());

        hoax(alice);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.deposit{value: 32 ether}(0);

        hoax(alice);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
    }

    function test_StakingManagerContractInstantiatedCorrectly() public {
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(stakingManagerInstance.owner(), owner);
    }

    function test_StakingManagerCorrectlyInstantiatesStakeObject() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.registerValidator(bidId, test_data);

        uint256 validatorId = bidId;
        uint256 winningBid = bidId;
        address staker = stakingManagerInstance.getStakerRelatedToValidator(
            validatorId
        );
        address etherfiNode = managerInstance.getEtherFiNodeAddress(
            validatorId
        );
        IStakingManager.DepositData memory deposit_data = IEtherFiNode(
            etherfiNode
        ).getDepositData();

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(stakingManagerInstance.stakeAmount(), 0.032 ether);
        assertEq(winningBid, bidId);
        assertEq(validatorId, bidId);

        assertEq(
            deposit_data.operator,
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(deposit_data.withdrawalCredentials, "test_credentials");
        assertEq(deposit_data.depositDataRoot, "test_deposit_root");
        assertEq(deposit_data.publicKey, "test_pubkey");
        assertEq(deposit_data.signature, "test_signature");
    }

    function test_StakingManagerReceivesEther() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
    }

    function test_StakingManagerFailsIfIncorrectAmountSent() public {
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        stakingManagerInstance.deposit{value: 0.2 ether}(0);
    }

    function test_StakingManagerFailsBidDoesntExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(proof);
        auctionInstance.cancelBid(1);
        vm.expectRevert("No bids available at the moment");
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
    }

    function test_StakingManagerfailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(proof);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        assertEq(stakingManagerInstance.paused(), true);
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        assertEq(stakingManagerInstance.paused(), false);
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
    }

    function test_EtherFailSafeWorks() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 walletBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        assertEq(address(stakingManagerInstance).balance, 0.032 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.132 ether
        );
        vm.stopPrank();

        vm.prank(owner);
        uint256 walletBalance2 = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;
        stakingManagerInstance.fetchEtherFromContract(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(address(stakingManagerInstance).balance, 0 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            walletBalance - 0.1 ether
        );
    }

    function test_RegisterValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.registerValidator(bidId, test_data);
    }

    function test_RegisterValidatorFailsIfValidatorNotInCorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.cancelDeposit(bidId);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.registerValidator(bidId, test_data);
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        vm.stopPrank();

        vm.prank(owner);
        stakingManagerInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        stakingManagerInstance.registerValidator(0, test_data);
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.registerValidator(bidId, test_data);

        uint256 selectedBidId = bidId;
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId);

        assertEq(etherFiNode.balance, 0.1 ether);
        assertEq(selectedBidId, 1);
        assertEq(managerInstance.numberOfValidators(), 1);
        assertEq(address(managerInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0);

        address operatorAddress = auctionInstance.getBidOwner(bidId);
        assertEq(operatorAddress, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        address safeAddress = managerInstance.getEtherFiNodeAddress(bidId);
        assertEq(safeAddress, etherFiNode);

        assertEq(
            TestBNFTInstance.ownerOf(bidId),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
    }

    function test_cancelDepositFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);

        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Not deposit owner");
        stakingManagerInstance.cancelDeposit(bidId);
    }

    function test_cancelDepositFailsIfCancellingAvailabilityClosed() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId = auctionInstance.createBid{value: 0.1 ether}(proof);

        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.cancelDeposit(bidId);

        vm.expectRevert("Deposit does not exist");
        stakingManagerInstance.cancelDeposit(bidId);
    }

    function test_cancelDepositWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId1 = auctionInstance.createBid{value: 0.1 ether}(proof);
        uint256 bidId2 = auctionInstance.createBid{value: 0.3 ether}(proof);
        uint256 bidId3 = auctionInstance.createBid{value: 0.2 ether}(proof);

        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.deposit{value: 0.032 ether}(0); // bidId2
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            .balance;

        uint256 selectedBidId = bidId2;
        address staker = stakingManagerInstance.getStakerRelatedToValidator(
            bidId2
        );
        address etherFiNode = managerInstance.getEtherFiNodeAddress(bidId2);

        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(selectedBidId, bidId2);
        assertTrue(
            IEtherFiNode(etherFiNode).getPhase() ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        (uint256 bidAmount, , , address bidder, bool isActive) = auctionInstance
            .bids(selectedBidId);

        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(auctionInstance.currentHighestBidId(), bidId3);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        stakingManagerInstance.cancelDeposit(bidId2);
        assertEq(managerInstance.getEtherFiNodeAddress(bidId2), address(0));
        assertEq(
            stakingManagerInstance.getStakerRelatedToValidator(bidId2),
            address(0)
        );
        assertTrue(
            IEtherFiNode(etherFiNode).getPhase() ==
                IEtherFiNode.VALIDATOR_PHASE.CANCELLED
        );

        (bidAmount, , , bidder, isActive) = auctionInstance.bids(bidId2);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(auctionInstance.currentHighestBidId(), bidId2);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            depositorBalance + 0.032 ether
        );
    }

    function test_CorrectValidatorAttatchedToNft() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        vm.prank(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorKeyManagerInstance.registerNodeOperator(_ipfsHash, 5);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256 bidId1 = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.registerValidator(bidId1, test_data);

        vm.stopPrank();
        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        uint256 bidId2 = auctionInstance.createBid{value: 0.1 ether}(proof);
        stakingManagerInstance.deposit{value: 0.032 ether}(0);
        stakingManagerInstance.registerValidator(bidId2, test_data);

        assertEq(
            TestBNFTInstance.ownerOf(bidId1),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId1),
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
        );
        assertEq(
            TestBNFTInstance.ownerOf(bidId2),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestTNFTInstance.ownerOf(bidId2),
            0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            1
        );
        assertEq(
            TestBNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
        );
        assertEq(
            TestTNFTInstance.balanceOf(
                0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf
            ),
            1
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
