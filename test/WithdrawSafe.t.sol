// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/interfaces/IWithdrawSafe.sol";
import "src/WithdrawSafeManager.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../src/BNFT.sol";
import "../src/NodeOperatorKeyManager.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";

contract WithdrawSafeTest is Test {
    IDeposit public depositInterface;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    NodeOperatorKeyManager public nodeOperatorKeyManagerInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    WithdrawSafe public safeInstance;
    WithdrawSafeManager public managerInstance;

    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IDeposit.DepositData public test_data;
    IDeposit.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);

    function setUp() public {
        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        nodeOperatorKeyManagerInstance = new NodeOperatorKeyManager();
        auctionInstance = new Auction(address(nodeOperatorKeyManagerInstance));
        treasuryInstance.setAuctionContractAddress(address(auctionInstance));
        auctionInstance.updateMerkleRoot(root);
        depositInstance = new Deposit(address(auctionInstance));
        auctionInstance.setDepositContractAddress(address(depositInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        managerInstance = new WithdrawSafeManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(depositInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance)
        );

        auctionInstance.setManagerAddress(address(managerInstance));
        depositInstance.setManagerAddress(address(managerInstance));

        test_data = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });

        test_data_2 = IDeposit.DepositData({
            operator: 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            withdrawalCredentials: "test_credentials_2",
            depositDataRoot: "test_deposit_root_2",
            publicKey: "test_pubkey_2",
            signature: "test_signature_2"
        });

        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        auctionInstance.bidOnStake{value: 0.1 ether}(proof);

        startHoax(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        depositInstance.setTreasuryAddress(address(treasuryInstance));
        depositInstance.deposit{value: 0.032 ether}();
        depositInstance.registerValidator(0, test_data);
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.acceptValidator(0);

        (, address withdrawSafe, , , , , ) = depositInstance.stakes(0);
        safeInstance = WithdrawSafe(payable(withdrawSafe));
    }

    function test_ReceiveAuctionFundsWorksCorrectly() public {
        assertEq(
            managerInstance.withdrawableBalance(
                0,
                IWithdrawSafeManager.ValidatorRecipientType.TREASURY
            ),
            10000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                0,
                IWithdrawSafeManager.ValidatorRecipientType.OPERATOR
            ),
            10000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                0,
                IWithdrawSafeManager.ValidatorRecipientType.BNFTHOLDER
            ),
            20000000000000000
        );
        assertEq(
            managerInstance.withdrawableBalance(
                0,
                IWithdrawSafeManager.ValidatorRecipientType.TNFTHOLDER
            ),
            60000000000000000
        );
        assertEq(address(safeInstance).balance, 0.1 ether);
        assertEq(address(managerInstance).balance, 0 ether);
    }

    function test_ReceiveAuctionFundsFailsIfNotAuctionContractCalling() public {
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
        managerInstance.withdrawFunds(0);
        assertEq(address(safeInstance).balance, 0 ether);
        assertEq(address(treasuryInstance).balance, 0.01040 ether);
        assertEq(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931.balance,
            operatorBalance + 0.0104 ether
        );
    }

    function test_WithdrawSafeMultipleSafesWorkCorrectly() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        hoax(alice);
        auctionInstance.bidOnStake{value: 0.4 ether}(proof);

        hoax(chad);
        auctionInstance.bidOnStake{value: 0.3 ether}(proof);

        hoax(bob);
        depositInstance.deposit{value: 0.032 ether}();

        hoax(dan);
        depositInstance.deposit{value: 0.032 ether}();

        (
            address staker_2,
            address withdrawSafeAddress_2,
            ,
            ,
            uint256 winningBidId_2,
            ,

        ) = depositInstance.stakes(1);

        (
            address staker_3,
            address withdrawSafeAddress_3,
            ,
            ,
            uint256 winningBidId_3,
            ,

        ) = depositInstance.stakes(2);

        assertEq(staker_2, bob);
        assertEq(staker_3, dan);

        startHoax(bob);
        depositInstance.registerValidator(1, test_data_2);
        vm.stopPrank();

        startHoax(dan);
        depositInstance.registerValidator(2, test_data_2);
        vm.stopPrank();

        hoax(alice);
        depositInstance.acceptValidator(1);

        hoax(chad);
        depositInstance.acceptValidator(2);

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
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(withdrawSafeAddress_2).call{value: 1 ether}("");
        require(sent, "Failed to send Ether");
        (sent, ) = address(withdrawSafeAddress_3).call{value: 10 ether}("");
        require(sent, "Failed to send Ether");
        vm.stopPrank();

        hoax(bob);
        managerInstance.withdrawFunds(1);

        hoax(dan);
        managerInstance.withdrawFunds(2);

        assertEq(withdrawSafeAddress_2.balance, 0);
        assertEq(withdrawSafeAddress_3.balance, 0);

        // Validator 2 Rewards
        uint256 aliceSplit = managerInstance.withdrawn(
            1,
            IWithdrawSafeManager.ValidatorRecipientType.OPERATOR
        );
        uint256 bobSplit = managerInstance.withdrawn(
            1,
            IWithdrawSafeManager.ValidatorRecipientType.TNFTHOLDER
        ) +
            managerInstance.withdrawn(
                1,
                IWithdrawSafeManager.ValidatorRecipientType.BNFTHOLDER
            );
        uint256 treasurySpilt = managerInstance.withdrawn(
            1,
            IWithdrawSafeManager.ValidatorRecipientType.TREASURY
        );

        // Validator 3 rewards
        uint256 chadSplit = managerInstance.withdrawn(
            2,
            IWithdrawSafeManager.ValidatorRecipientType.OPERATOR
        );
        uint256 danSplit = managerInstance.withdrawn(
            2,
            IWithdrawSafeManager.ValidatorRecipientType.TNFTHOLDER
        ) +
            managerInstance.withdrawn(
                2,
                IWithdrawSafeManager.ValidatorRecipientType.BNFTHOLDER
            );
        treasurySpilt += managerInstance.withdrawn(
            2,
            IWithdrawSafeManager.ValidatorRecipientType.TREASURY
        );

        assertEq(alice.balance, aliceBalBefore + aliceSplit);
        assertEq(chad.balance, chadBalBefore + chadSplit);

        assertEq(bob.balance, bobBalBefore + bobSplit);
        assertEq(dan.balance, danBalBefore + danSplit);

        assertEq(
            address(treasuryInstance).balance,
            treasuryBalBefore + treasurySpilt
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
