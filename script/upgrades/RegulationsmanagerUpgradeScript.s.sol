// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/RegulationsManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RegulationsManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address RegulationsManagerProxyAddress = vm.envAddress("REGULATIONS_MANAGER_PROXY_ADDRESS");

        // mainnet
        //require(RegulationsManagerProxyAddress ==, "RegulationsManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        RegulationsManager RegulationsManagerInstance = RegulationsManager(RegulationsManagerProxyAddress);
        RegulationsManager RegulationsManagerV2Implementation = new RegulationsManager();

        RegulationsManagerInstance.upgradeTo(address(RegulationsManagerV2Implementation));
        RegulationsManager RegulationsManagerV2Instance = RegulationsManager(RegulationsManagerProxyAddress);

        vm.stopBroadcast();
    }
}