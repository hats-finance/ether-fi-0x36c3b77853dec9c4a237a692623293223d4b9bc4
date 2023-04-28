pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Treasury.sol";

contract DeployTreasuryTestScript is Script {
    Treasury public treasury;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        treasury = new Treasury();

        vm.stopBroadcast();
    }
}