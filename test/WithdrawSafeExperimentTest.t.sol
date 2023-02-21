// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/interfaces/IDeposit.sol";
import "../src/interfaces/IWithdrawSafe.sol";
import "src/WithdrawSafeManager.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../src/BNFT.sol";
import "../src/Registration.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../lib/murky/src/Merkle.sol";
import "../src/SykoWithdrawSafe.sol";

contract WithdrawSafeExperimentTest is Test {
    IDeposit public depositInterface;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Registration public registrationInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    WithdrawSafeManager public managerInstance;

    Merkle merkle;
    bytes32 root;
    bytes32[] public whiteListedAddresses;

    IDeposit.DepositData public test_data;

    uint256 num_operators;
    uint256 num_stakers;
    address[] operators;
    address[] stakers;
    uint256[] validatorIds;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);

    function setUp() public {
        num_operators = 1; // should be 1
        num_stakers = 16;
        for (uint i = 0; i < num_operators; i++) {
            operators.push(vm.addr(i+1));
        }
        for (uint i = 0; i < num_stakers; i++) {
            stakers.push(vm.addr(i+10000));
        }        

        vm.startPrank(owner);
        treasuryInstance = new Treasury();
        _merkleSetup();
        registrationInstance = new Registration();
        auctionInstance = new Auction(address(registrationInstance));
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
            operator: operators[0],
            withdrawalCredentials: "test_credentials",
            depositDataRoot: "test_deposit_root",
            publicKey: "test_pubkey",
            signature: "test_signature"
        });
        vm.stopPrank();

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        startHoax(operators[0]);
        for (uint i = 0; i < num_stakers; i++) {
            auctionInstance.bidOnStake{value: 0.1 ether}(proof);
        }
        vm.stopPrank();

        for (uint i = 0; i < num_stakers; i++) {
            startHoax(stakers[i]);
            depositInstance.setTreasuryAddress(address(treasuryInstance));
            depositInstance.deposit{value: 0.032 ether}();
            depositInstance.registerValidator(i, test_data);
            vm.stopPrank();
        }

        startHoax(operators[0]);
        for (uint i = 0; i < num_stakers; i++) {
            depositInstance.acceptValidator(i);   
            validatorIds.push(i);
        }
        vm.stopPrank();

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        for (uint i = 0; i < num_stakers; i++) {
            (, address withdrawSafe, , , , , ) = depositInstance.stakes(i);
            WithdrawSafe safeInstance = WithdrawSafe(payable(withdrawSafe)); 

            (bool sent, ) = address(safeInstance).call{value: 0.01 ether}("");
            require(sent, "Failed to send Ether");
        }
        vm.stopPrank();

        // for (uint i = 0; i < num_stakers; i++) {
        //     vm.startPrank(stakers[i]);
        //     uint256 balance = address(stakers[i]).balance;
        //     (bool sent, ) = address(operators[0]).call{value: balance}("");
        //     require(sent, "Failed to send Ether");
        //     vm.stopPrank();
        // }
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

    function test_hi() public {

    }

    function test_partialWithdrawBatchWorksCorrectly() public {
        uint256 beforeBalance = address(operators[0]).balance;

        startHoax(operators[0]);
        // for (uint i = 0; i < num_stakers; i++) {
        //     managerInstance.partialWithdraw(validatorIds[i]);
        // }
        managerInstance.partialWithdrawBatch(operators[0], validatorIds);
        // managerInstance.partialWithdrawBatch(operators[0], stakers[0], stakers[1], validatorIds);
        vm.stopPrank();

        // for (uint i = 0; i < num_stakers; i++) {
        //     (, address withdrawSafe, , , , , ) = depositInstance.stakes(i);
        //     WithdrawSafe safeInstance = WithdrawSafe(payable(withdrawSafe)); 
        //     assertEq(address(safeInstance).balance, 0 ether);
        // }

        uint256 afterBalance = address(operators[0]).balance;
        console.log(afterBalance - beforeBalance);

        // assertEq(address(safeInstance).balance, 0 ether);
        // assertEq(address(treasuryInstance).balance, 0.007 ether);
        // assertEq(address(operator).balance, operatorBalance + 0.007 ether);
    }

}
