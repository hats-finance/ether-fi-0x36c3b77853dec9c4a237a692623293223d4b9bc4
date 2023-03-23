// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TestToken.sol";
import "../src/LiquidityPool.sol";
import "../src/ConversionPool.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/EETH.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployGoerliSwapTestSuiteScript is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TestToken rEth = new TestToken("Rocket Pool ETH", "rETH");
        TestToken wstEth = new TestToken("Staked ETH", "wstETH");
        TestToken sfrxEth = new TestToken("Frax ETH", "sfrxEth");
        TestToken cbEth = new TestToken("Coinbase ETH", "cbEth");

        LiquidityPool liquidityPool = new LiquidityPool(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);

        EETH eEth = new EETH(address(liquidityPool));

        EarlyAdopterPool earlyAdopterPool = new EarlyAdopterPool(
            address(rEth),
            address(wstEth),
            address(sfrxEth),
            address(cbEth)
        );

        ConversionPool conversionPool = new ConversionPool(
            0xE592427A0AEce92De3Edee1F18E0157C05861564,
            address(liquidityPool),
            address(earlyAdopterPool),
            address(rEth),
            address(wstEth),
            address(sfrxEth),
            address(cbEth),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );

        vm.stopBroadcast();
    }
}
