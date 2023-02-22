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
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";


contract WithdrawSafeExperimentTest is Test {
    IDeposit public depositInterface;
    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Registration public registrationInstance;
    Auction public auctionInstance;
    Treasury public treasuryInstance;
    WithdrawSafeManager public managerInstance;
    LiquidityPool public liquidityPool;
    EETH public eETH;

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

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);

    function setUp() public {
        num_operators = 1; // should be 1
        num_stakers = 16;
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
        liquidityPool = new LiquidityPool(owner);
        eETH = new EETH(address(liquidityPool));
        liquidityPool.setTokenAddress(address(eETH));

        managerInstance = new WithdrawSafeManager(
            address(treasuryInstance),
            address(auctionInstance),
            address(depositInstance),
            address(TestTNFTInstance),
            address(TestBNFTInstance),
            address(liquidityPool)
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
            eETH.mint(address(safeInstance), 1);
            
        }
        vm.stopPrank();

        for (uint i = 0; i < num_stakers; i++) {
            vm.startPrank(stakers[i]);
            TestTNFTInstance.transferFrom(stakers[i], people[i], i);
        //     uint256 balance = address(stakers[i]).balance;
        //     (bool sent, ) = address(operators[0]).call{value: balance}("");
        //     require(sent, "Failed to send Ether");
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
        vm.deal(address(managerInstance), 100 ether);
        for (uint i = 0; i < num_stakers; i++) {
            (, address withdrawSafe, , , , , ) = depositInstance.stakes(i);
            WithdrawSafe safeInstance = WithdrawSafe(payable(withdrawSafe)); 
            
            vm.deal(address(safeInstance), 1 ether);
            vm.deal(stakers[i], 1 ether);
            vm.deal(people[i], 1 ether);
            
            eETH.mint(address(safeInstance), 1);            
            eETH.mint(stakers[i], 1);
            eETH.mint(people[i], 1);
        }
        eETH.mint(operators[0], 1);
        eETH.mint(address(treasuryInstance), 1);
        eETH.mint(address(liquidityPool), 1);
    }

    function test_partialWithdraw_batch_base() public {
        _deals();
        startHoax(operators[0]);
        for (uint i = 0; i < num_stakers; i++) {
            managerInstance.partialWithdraw(validatorIds[i]);
        }
        vm.stopPrank();
    }

    function test_partialWithdrawBatchByMintingEETH() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchByMintingEETH(operators[0], validatorIds);
        vm.stopPrank();
    }
    
    function test_partialWithdrawBatchByMintingEETHForTNftInLiquidityPool() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchByMintingEETHForTNftInLiquidityPool(operators[0], validatorIds);
        vm.stopPrank();
    }
    
    function test_partialWithdrawBatch() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatch(operators[0], validatorIds);
        vm.stopPrank();
    }
    
    function test_partialWithdrawBatchForTNftInLiquidityPool() public {
        _deals();
        startHoax(operators[0]);
        managerInstance.partialWithdrawBatchForTNftInLiquidityPool(operators[0], validatorIds);
        vm.stopPrank();
    }

}
