// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract DepositTest is Test {
    IDeposit public depositInterface;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        _merkleSetup();
        treasuryInstance = new Treasury();
        auctionInstance = new Auction(address(treasuryInstance));
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));     
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance));
        depositInterface = IDeposit(address(depositInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function test_DepositContractInstantiatedCorrectly() public {
        assertEq(depositInstance.stakeAmount(), 0.032 ether);
        assertEq(depositInstance.owner(), owner);
    }

    function test_DepositReceivesEther() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        assertEq(address(depositInstance).balance, 0.032 ether);
    }

    function test_DepositUpdatesBalancesMapping() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.032 ether
        );
    
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data_2");
        assertEq(
            depositInstance.depositorBalances(
                0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931
            ),
            0.064 ether
        );
    }

    function test_DepositFailsIfIncorrectAmountSent() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Insufficient staking amount");
        depositInstance.deposit{value: 0.2 ether}("test_data");
    }

    function test_DepositFailsBidDoesntExist() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.cancelBid(1);
        vm.expectRevert("No bids available at the moment");
        depositInstance.deposit{value: 0.032 ether}("test_data");
    }

    function test_DepositfailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(owner);
        depositInstance.pauseContract();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        vm.expectRevert("Pausable: paused");
        depositInstance.deposit{value: 0.032 ether}("test_data");
        assertEq(depositInstance.paused(), true);
        vm.stopPrank();

        vm.prank(owner);
        depositInstance.unPauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        assertEq(depositInstance.paused(), false);
        assertEq(address(depositInstance).balance, 0.032 ether);
    }

    function test_RegisterValidatorFailsIfIncorrectCaller() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        vm.stopPrank();

        vm.prank(owner);
        vm.expectRevert("Incorrect caller");
        depositInstance.registerValidator(0, "validator_key");
    }

    function test_RegisterValidatorFailsIfStakeNotInCorrectPhase() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        depositInstance.cancelStake(0);

        vm.expectRevert("Stake not in correct phase");
        depositInstance.registerValidator(0, "validator_key");
    }

    function test_RegisterValidatorFailsIfContractPaused() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");
        vm.stopPrank();

        vm.prank(owner);
        depositInstance.pauseContract();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("Pausable: paused");
        depositInstance.registerValidator(0, "validator_key");
    }

    function test_RegisterValidatorWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        depositInstance.deposit{value: 0.032 ether}("test_data");

        depositInstance.registerValidator(0, "validator_key");

        (uint256 bidId, uint256 stakeId, bytes memory validatorKey,) = depositInstance.validators(0);
        assertEq(bidId, 1);
        assertEq(stakeId, 0);
        assertEq(validatorKey, "validator_key");
        assertEq(depositInstance.numberOfValidators(), 1);
    }

    function test_RefundWorksCorrectly() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        uint256 balanceOne = address(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931).balance;

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.bidOnStake{value: 0.3 ether}(proof);
        uint256 balanceTwo = address(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931).balance;
        
        assertEq(balanceTwo, balanceOne - 0.4 ether);

        depositInstance.deposit{value: 0.032 ether}("test_data");
        depositInstance.deposit{value: 0.032 ether}("test_data_2");
        uint256 balanceThree = address(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931).balance;
        
        assertEq(balanceThree, balanceTwo - 0.064 ether);
        assertEq(address(depositInstance).balance, 0.064 ether);
        assertEq(depositInstance.depositorBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.064 ether);

        depositInstance.cancelStake(0);
        (,,uint256 amount,,,) = depositInstance.stakes(0);
        uint256 balanceFour = address(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931).balance;

        assertEq(depositInstance.depositorBalances(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.032 ether);
        assertEq(balanceFour, balanceThree + 0.032 ether);
        assertEq(address(depositInstance).balance, 0.032 ether);
        assertEq(amount, 0.032 ether);
    }

    function test_CancelStakeFailsIfNotStakeOwner() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        depositInstance.deposit{value: 0.032 ether}("test_data");
        vm.stopPrank();
        vm.prank(owner);
        vm.expectRevert("Not bid owner");
        depositInstance.cancelStake(0);
    }

    function test_CancelStakeFailsIfCancellingAvailabilityClosed() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        depositInstance.deposit{value: 0.032 ether}("test_data");
        depositInstance.cancelStake(0);

        vm.expectRevert("Cancelling availability closed");
        depositInstance.cancelStake(0);
    }

    function test_CancelStakeWorksCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        auctionInstance.bidOnStake{value: 0.3 ether}(proof);
        auctionInstance.bidOnStake{value: 0.2 ether}(proof);
        assertEq(address(treasuryInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        depositInstance.deposit{value: 0.032 ether}("test_data");
        uint256 depositorBalance = 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance;
        (address staker,bytes memory deposit_data,uint256 amount,uint256 winningbidID,,) = depositInstance.stakes(0);
        assertEq(staker, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(amount, 0.032 ether);
        assertEq(winningbidID, 2);
        assertEq(deposit_data, "test_data");

        (uint256 bidAmount,, address bidder, bool isActive) = auctionInstance.bids(winningbidID);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, false);
        assertEq(auctionInstance.numberOfActiveBids(), 2);
        assertEq(auctionInstance.currentHighestBidId(), 3);
        assertEq(address(treasuryInstance).balance, 0.3 ether);
        assertEq(address(auctionInstance).balance, 0.3 ether);

        depositInstance.cancelStake(0);
        (,,,winningbidID,,) = depositInstance.stakes(0);
        assertEq(winningbidID, 0);

        (bidAmount,, bidder, isActive) = auctionInstance.bids(2);
        assertEq(bidAmount, 0.3 ether);
        assertEq(bidder, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        assertEq(isActive, true);
        assertEq(auctionInstance.numberOfActiveBids(), 3);
        assertEq(auctionInstance.currentHighestBidId(), 2);
        assertEq(address(treasuryInstance).balance, 0 ether);
        assertEq(address(auctionInstance).balance, 0.6 ether);

        assertEq(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance, depositorBalance + 0.032 ether);

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
