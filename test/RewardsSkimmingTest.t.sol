// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract RewardsSkimmingTest is TestSetup {
    uint256 num_operators;
    uint256 num_stakers;
    uint256 num_people;
    address[] operators;
    address[] stakers;
    address[] people;
    uint256[] validatorIds;

    uint256[] validatorIdsOfMixedTNftHolders;
    uint256[] validatorIdsOfTNftsInLiquidityPool;

    uint256[] bidId;

    bytes32 newRoot;
    bytes32[] public newWhiteListedAddresses;
    
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

        setUpTests();
        _setupMerkle();

        vm.prank(owner);
        nodeOperatorManagerInstance.updateMerkleRoot(newRoot);

        bytes32[] memory proof = merkle.getProof(newWhiteListedAddresses, 1);

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
                TNFTInstance.transferFrom(stakers[i], people[i], validatorIds[i]);
            } else {
                TNFTInstance.transferFrom(stakers[i], liquidityPool, validatorIds[i]);
            }
            vm.stopPrank();
        }        
    }

    function _setupMerkle() internal {
        merkle = new Merkle();
        newWhiteListedAddresses.push(
            keccak256(
                abi.encodePacked(operators[0])
            )
        );
        newWhiteListedAddresses.push(
            keccak256(
                abi.encodePacked(operators[0])
            )
        );
        newRoot = merkle.getRoot(newWhiteListedAddresses);
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