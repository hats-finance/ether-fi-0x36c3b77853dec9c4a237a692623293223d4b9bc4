// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/EtherFiNodesManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EtherFiNodesManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address EtherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(EtherFiNodesManagerProxyAddress == 0x8B71140AD2e5d1E7018d2a7f8a288BD3CD38916F, "EtherFiNodesManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        EtherFiNodesManager EtherFiNodesManagerInstance = EtherFiNodesManager(payable(EtherFiNodesManagerProxyAddress));
        EtherFiNodesManager EtherFiNodesManagerV2Implementation = new EtherFiNodesManager();

        EtherFiNodesManagerInstance.upgradeTo(address(EtherFiNodesManagerV2Implementation));
        EtherFiNodesManager EtherFiNodesManagerV2Instance = EtherFiNodesManager(payable(EtherFiNodesManagerProxyAddress));

        vm.stopBroadcast();
    }
}