// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MainnetTestSetup.sol";
import "../../src/helpers/AddressProvider.sol";

contract RebaseTest is MainnetTestSetup {

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

    // It shows the results of the wrong Negative rebase that occured at BlockNumber = 18312554
    function test_fork_rebase1() public {
        uint256 fork1 = vm.createFork(MAINNET_RPC_URL, 18312554 - 1);
        uint256 fork2 = vm.createFork(MAINNET_RPC_URL, 18312554);

        vm.selectFork(fork1);
        uint256 tvl1 = liquidityPoolInstance.getTotalPooledEther();
        console.log(block.number, liquidityPoolInstance.getTotalPooledEther(), membershipManagerInstance.rewardsGlobalIndex(2));
        //   18312553 9161186217864189118287 23361416952715484

        vm.selectFork(fork2);
        uint256 tvl2 = liquidityPoolInstance.getTotalPooledEther();
        console.log(block.number, liquidityPoolInstance.getTotalPooledEther(), membershipManagerInstance.rewardsGlobalIndex(2));
        //   18312554 9158538124899021509531 23361416952715484

        // Negative rebase happened while not taking the distributed rewards back
        assertEq(9161186217864189118287 - 9158538124899021509531, tvl1 - tvl2);
    }

    function test_fork_rebase2() public {
        uint256 fork1 = vm.createFork(MAINNET_RPC_URL);
        uint256 diff = 0.0 ether;

        vm.selectFork(fork1);
        uint256 tvl1 = liquidityPoolInstance.getTotalPooledEther();
        console.log(block.number, liquidityPoolInstance.getTotalPooledEther());
        console.log(membershipManagerInstance.rewardsGlobalIndex(0), membershipManagerInstance.rewardsGlobalIndex(1), membershipManagerInstance.rewardsGlobalIndex(2), membershipManagerInstance.rewardsGlobalIndex(3));

        vm.prank(membershipManagerInstance.admin());
        membershipManagerInstance.rebase(tvl1 + diff, address(liquidityPoolInstance).balance);

        console.log(block.number, liquidityPoolInstance.getTotalPooledEther());
        console.log(membershipManagerInstance.rewardsGlobalIndex(0), membershipManagerInstance.rewardsGlobalIndex(1), membershipManagerInstance.rewardsGlobalIndex(2), membershipManagerInstance.rewardsGlobalIndex(3));
    }

    // It shows how to fix the wrong Negative rebase that occured at BlockNumber = 18312554
    function test_fork_rebase3() public {
        // Based on the latest block on mainnet
        uint256 fork3 = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(fork3);

        address gnosis = liquidityPoolInstance.owner();
        address membershipManagerAddress = address(membershipManagerInstance);

        // Transaction 1
        // Pause the MembershipManager contract so that no user can interact with it
        vm.prank(membershipManagerInstance.admin());
        membershipManagerInstance.pauseContract();

        // Transaction 2
        // Revert the negative rebase == Rebase with ~1.3 ETH
        // 9161186217864189118287 - 9158538124899021509531 = 2648092965167608756
        // uint256 diff = 9161186217864189118287 - 9158538124899021509531;
        uint256 diff = 0.8 ether;

        uint256 tvl1 = liquidityPoolInstance.getTotalPooledEther();
        uint256 rgi2_1 = membershipManagerInstance.rewardsGlobalIndex(2);
        console.log(block.number, liquidityPoolInstance.getTotalPooledEther(), membershipManagerInstance.rewardsGlobalIndex(2));

        vm.prank(gnosis);
        liquidityPoolInstance.setMembershipManager(gnosis);

        vm.prank(gnosis);
        console.log(tvl1 + diff, address(liquidityPoolInstance).balance);
        liquidityPoolInstance.rebase(tvl1 + diff, address(liquidityPoolInstance).balance);

        vm.prank(gnosis);
        liquidityPoolInstance.setMembershipManager(membershipManagerAddress);

        // Transaction 3
        // UnPause the MembershipManager contract
        vm.prank(membershipManagerInstance.admin());
        membershipManagerInstance.unPauseContract();

        // RewardsGlobalIndex didn't change == Rewards not distributed
        assertEq(rgi2_1, membershipManagerInstance.rewardsGlobalIndex(2));

        console.log(block.number, liquidityPoolInstance.getTotalPooledEther(), membershipManagerInstance.rewardsGlobalIndex(2));
    }

}