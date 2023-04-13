pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract EETHTest is TestSetup {

    function setUp() public {
       
        setUpTests();
    }

    function test_EETHInitializedCorrectly() public {
        assertEq(eETHInstance.totalShares(), 0);
        assertEq(eETHInstance.name(), "ether.fi ETH");
        assertEq(eETHInstance.symbol(), "eETH");
        assertEq(eETHInstance.decimals(), 18);
        assertEq(eETHInstance.totalSupply(), 0);
        assertEq(eETHInstance.balanceOf(alice), 0);
        assertEq(eETHInstance.balanceOf(bob), 0);
        assertEq(eETHInstance.allowance(alice, bob), 0);
        assertEq(eETHInstance.allowance(alice, address(liquidityPoolInstance)), 0);
        assertEq(eETHInstance.shares(alice), 0);
        assertEq(eETHInstance.shares(bob), 0);
        assertEq(eETHInstance.getImplementation(), address(eETHImplementation));
    }

    function test_MintShares() public {
        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(alice, 100);

        assertEq(eETHInstance.shares(alice), 100);
        assertEq(eETHInstance.totalShares(), 100);

        assertEq(eETHInstance.balanceOf(alice), 0);
        assertEq(eETHInstance.totalSupply(), 0);
    }

    function test_EEthRebase() public {
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 0 ether);

        // Total pooled ether = 10
        vm.deal(address(liquidityPoolInstance), 10 ether);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);

        // Total pooled ether = 20
        hoax(alice);
        liquidityPoolInstance.deposit{value: 10 ether}(alice);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 20 ether);

        // ALice is first so get 100% of shares
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        // ALice total claimable Ether
        /// (20 * 10) / 10
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 20 ether);

        hoax(bob);
        liquidityPoolInstance.deposit{value: 5 ether}(bob);

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 25 ether);

        // Bob Shares = (5 * 10) / (25 - 5) = 2,5
        assertEq(eETHInstance.shares(bob), 2.5 ether);
        assertEq(eETHInstance.totalShares(), 12.5 ether);

        // console.logUint(eETHInstance.shares(alice));
        // console.logUint(eETHInstance.shares(bob));

        // Bob claimable Ether
        /// (25 * 2,5) / 12,5 = 5 ether

        //ALice Claimable Ether
        /// (25 * 10) / 12,5 = 20 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 20 ether);
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 5 ether);

        // Staking Rewards sent to liquidity pool
        // vm.deal sets the balance of whoever its called on
        /// In this case 10 ether is added as reward 
        vm.deal(address(liquidityPoolInstance), 35 ether);
        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 35 ether);

        // Bob claimable Ether
        /// (35 * 2,5) / 12,5 = 7 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(bob), 7 ether);

        //ALice Claimable Ether
        /// (35 * 10) / 12,5 = 20 ether
        assertEq(liquidityPoolInstance.getTotalEtherClaimOf(alice), 28 ether);
    }

}