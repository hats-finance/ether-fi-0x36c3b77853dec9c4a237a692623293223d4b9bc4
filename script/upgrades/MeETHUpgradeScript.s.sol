// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/meETH.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MeETHUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address meETHProxyAddress = vm.envAddress("MeETH_PROXY_ADDRESS");

        // mainnet
        //require(meETHProxyAddress == , "meETHProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        meETH meETHInstance = meETH(payable(meETHProxyAddress));
        meETH meETHV2Implementation = new meETH();

        meETHInstance.upgradeTo(address(meETHV2Implementation));
        meETH meETHV2Instance = meETH(payable(meETHProxyAddress));

        vm.stopBroadcast();
    }
}