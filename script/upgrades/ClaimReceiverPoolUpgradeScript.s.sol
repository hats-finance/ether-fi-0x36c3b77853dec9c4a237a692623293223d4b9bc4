// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/ClaimReceiverPool.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ClaimReceiverPoolUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ClaimReceiverPoolProxyAddress = vm.envAddress("CLAIM_RECEIVER_POOL_PROXY_ADDRESS");

        // mainnet
        //require(ClaimReceiverPoolProxyAddress == , "ClaimReceiverPoolProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        ClaimReceiverPool ClaimReceiverPoolInstance = ClaimReceiverPool(ClaimReceiverPoolProxyAddress);
        ClaimReceiverPool ClaimReceiverPoolV2Implementation = new ClaimReceiverPool();

        ClaimReceiverPoolInstance.upgradeTo(address(ClaimReceiverPoolV2Implementation));
        ClaimReceiverPool ClaimReceiverPoolV2Instance = ClaimReceiverPool(ClaimReceiverPoolProxyAddress);

        vm.stopBroadcast();
    }
}