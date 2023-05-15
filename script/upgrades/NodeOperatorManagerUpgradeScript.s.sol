// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/NodeOperatorManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NodeOperatorManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address NodeOperatorManagerProxyAddress = vm.envAddress("NODE_OPERATOR_MANAGER_PROXY_ADDRESS");

        // mainnet
        //require(NodeOperatorManagerProxyAddress == , "NodeOperatorManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        NodeOperatorManager NodeOperatorManagerInstance = NodeOperatorManager(NodeOperatorManagerProxyAddress);
        NodeOperatorManager NodeOperatorManagerV2Implementation = new NodeOperatorManager();

        NodeOperatorManagerInstance.upgradeTo(address(NodeOperatorManagerV2Implementation));
        NodeOperatorManager NodeOperatorManagerV2Instance = NodeOperatorManager(NodeOperatorManagerProxyAddress);

        vm.stopBroadcast();
    }
}