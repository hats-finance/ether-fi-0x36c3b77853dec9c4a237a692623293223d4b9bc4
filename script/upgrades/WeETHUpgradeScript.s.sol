// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/weEth.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WeEthUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address weEthProxyAddress = vm.envAddress("WEETH_PROXY_ADDRESS");

        // mainnet
        //require(weEthProxyAddress == , "weEthProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        weEth weEthInstance = weEth(weEthProxyAddress);
        weEth weEthV2Implementation = new weEth();

        weEthInstance.upgradeTo(address(weEthV2Implementation));
        weEth weEthV2Instance = weEth(weEthProxyAddress);

        vm.stopBroadcast();
    }
}