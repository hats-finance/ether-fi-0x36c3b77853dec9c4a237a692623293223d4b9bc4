// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MainnetTestSetup.sol";

contract AuctionManagerMainnetTest is MainnetTestSetup {

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        setUpTests();
    }

    function test_AuctionManagerContractInstantiatedCorrectlyOnMainnet() public {
        assertEq(
            auctionManagerInstance.stakingManagerContractAddress(),
            0x25e821b7197B146F7713C3b89B6A4D83516B912d
        );
        console.log(auctionManagerInstance.numberOfActiveBids());
    }

    function test_WhatHappensWhenCreatingNewBid() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        assertEq(regulationsManagerInstance.isEligible(3, alice), false);
        regulationsManagerInstance.confirmEligibility(0x0ab8550a37ce88b186c3e9887c7c9914b413f7330155bf4086c8035847c6c6b4);
        assertEq(regulationsManagerInstance.isEligible(3, alice), true);

    }
}
