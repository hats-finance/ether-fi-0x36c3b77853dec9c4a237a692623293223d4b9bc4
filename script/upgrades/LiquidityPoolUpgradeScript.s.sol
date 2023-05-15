// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/LiquidityPool.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LiquidityPoolUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address LiquidityPoolProxyAddress = vm.envAddress("LIQUIDITY_POOL_PROXY_ADDRESS");

        // mainnet
        //require(LiquidityPoolProxyAddress == , "LiquidityPoolProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        LiquidityPool LiquidityPoolInstance = LiquidityPool(payable(LiquidityPoolProxyAddress));
        LiquidityPool LiquidityPoolV2Implementation = new LiquidityPool();

        LiquidityPoolInstance.upgradeTo(address(LiquidityPoolV2Implementation));
        LiquidityPool LiquidityPoolV2Instance = LiquidityPool(payable(LiquidityPoolProxyAddress));

        vm.stopBroadcast();
    }
}