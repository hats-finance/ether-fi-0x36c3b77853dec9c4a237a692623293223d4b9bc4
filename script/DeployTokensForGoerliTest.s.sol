// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/EETH.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployTokensForGoerliTestScript is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EETH eEth = new EETH(0xF6cFB7fb4705f918c411756C0d6651610E6750c6);

        vm.stopBroadcast();
    }
}
