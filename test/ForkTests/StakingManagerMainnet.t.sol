// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MainnetTestSetup.sol";

contract StakingManagerMainnetTest is MainnetTestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public zeroProof;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        setUpTests();
    }

    function test_StakingManagerContractInstantiatedCorrectlyOnMainnet() public {
        assertEq(
            stakingManagerInstance.stakeAmount(),
            32 ether
        );
    }

    function test_BatchDeposit() public {
        vm.deal(alice, 1000);
        startHoax(alice);

        uint256 numberOfActiveBidsBefore = auctionManagerInstance.numberOfActiveBids();
     
        console.log("Number of active bids currently: ", numberOfActiveBidsBefore);

        uint256[] memory bidIdArray = new uint256[](4);
        bidIdArray[0] = 200;
        bidIdArray[1] = 201;
        bidIdArray[2] = 202;
        bidIdArray[3] = 203;
        uint256[] memory processedBids = stakingManagerInstance.batchDepositWithBidIds{value: 128 ether}(bidIdArray, zeroProof);

        console.log("Number of active bids currently: ", auctionManagerInstance.numberOfActiveBids());
        assertEq(auctionManagerInstance.numberOfActiveBids(), numberOfActiveBidsBefore - 4);

        (, , , bool isActive) = auctionManagerInstance.bids(processedBids[0]);
        assertEq(isActive, false);
    }
}
