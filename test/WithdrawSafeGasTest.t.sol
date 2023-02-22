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


contract WithdrawSafeGasTest is Test {
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
    uint256 num_people;
    address[] operators;
    address[] stakers;
    address[] people;
    uint256[] validatorIds;

    uint256[] validatorIdsOfMixedTNftHolders;
    uint256[] validatorIdsOfTNftsInLiquidityPool;


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
            if (i % 2 == 0) {
                validatorIdsOfMixedTNftHolders.push(i);
            } else {
                validatorIdsOfTNftsInLiquidityPool.push(i);
            }
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

        // Mix the T-NFT holders
        for (uint i = 0; i < num_stakers; i++) {
            vm.startPrank(stakers[i]);
            if (i % 2 == 0) {
                TestTNFTInstance.transferFrom(stakers[i], people[i], i);
            } else {
                TestTNFTInstance.transferFrom(stakers[i], liquidityPool, i);
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
            (, address withdrawSafe, , , , , ) = depositInstance.stakes(i);
            WithdrawSafe safeInstance = WithdrawSafe(payable(withdrawSafe)); 
            
            vm.deal(address(safeInstance), 1 ether);
            vm.deal(stakers[i], 1 ether);
            vm.deal(people[i], 1 ether);
        }
    }

    function test_partialWithdraw_batch_base() public {
        _deals();
        startHoax(operators[0]);
        for (uint i = 0; i < num_stakers/2; i++) {
            managerInstance.partialWithdraw(validatorIds[i]);
        }
        vm.stopPrank();
    }
    
    function test_partialWithdrawBatch() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchForOperator(operators[0], validatorIdsOfMixedTNftHolders);
        vm.stopPrank();
    }
    
    function test_partialWithdrawBatchForTNftInLiquidityPool() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchForOperatorAndTNftHolder(operators[0], liquidityPool, validatorIdsOfTNftsInLiquidityPool);
        vm.stopPrank();
    }

}