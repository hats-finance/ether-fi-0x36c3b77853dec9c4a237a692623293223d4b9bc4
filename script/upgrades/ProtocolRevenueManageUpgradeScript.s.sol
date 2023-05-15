// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/ProtocolRevenueManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ProtocolRevenueManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ProtocolRevenueManagerProxyAddress = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(ProtocolRevenueManagerProxyAddress == 0xfE8A8FC74B2fdD3D745AbFc4940DD858BA60696c, "ProtocolRevenueManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        ProtocolRevenueManager ProtocolRevenueManagerInstance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));
        ProtocolRevenueManager ProtocolRevenueManagerV2Implementation = new ProtocolRevenueManager();

        ProtocolRevenueManagerInstance.upgradeTo(address(ProtocolRevenueManagerV2Implementation));
        ProtocolRevenueManager ProtocolRevenueManagerV2Instance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));

        vm.stopBroadcast();
    }
}