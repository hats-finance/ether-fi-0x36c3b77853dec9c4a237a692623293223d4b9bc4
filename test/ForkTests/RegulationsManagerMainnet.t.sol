// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MainnetTestSetup.sol";

contract RegulationsManagerMainnetTest is MainnetTestSetup {

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        setUpTests();
    }

    function test_RegulationsManagerContractInstantiatedCorrectlyOnMainnet() public {
        assertEq(
            regulationsManagerInstance.owner(),
            0xF155a2632Ef263a6A382028B3B33feb29175b8A5
        );
        console.log(regulationsManagerInstance.whitelistVersion());
    }

    function test_ConfirmingEligibility() public {
        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        assertEq(regulationsManagerInstance.isEligible(3, alice), false);
        regulationsManagerInstance.confirmEligibility(0x0ab8550a37ce88b186c3e9887c7c9914b413f7330155bf4086c8035847c6c6b4);
        assertEq(regulationsManagerInstance.isEligible(3, alice), true);

    }
}
