// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/EETH.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EETHUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address EETHProxyAddress = vm.envAddress("EETH_PROXY_ADDRESS");

        // mainnet
        //require(EETHProxyAddress == , "EETHProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        EETH EETHInstance = EETH(EETHProxyAddress);
        EETH EETHV2Implementation = new EETH();

        EETHInstance.upgradeTo(address(EETHV2Implementation));
        EETH EETHV2Instance = EETH(EETHProxyAddress);

        vm.stopBroadcast();
    }
}