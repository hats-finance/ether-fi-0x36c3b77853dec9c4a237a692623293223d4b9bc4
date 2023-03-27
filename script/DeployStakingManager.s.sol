// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StakingManagerDeployScript is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManager = new StakingManager(
            0xa330fF6cc6B4d3DAb9ef9706Dfa7b1A30A466250
        );   

        stakingManager.setEtherFiNodesManagerAddress(
            0x1f5dc22Aad6812D7ebCC0A07b0E04C9e5C6C85bb
        );

        stakingManager.setTreasuryAddress(0xc8dAc0d35f26fec2056d3d3Be1686181e650A045);

        vm.stopBroadcast();
    }
}
