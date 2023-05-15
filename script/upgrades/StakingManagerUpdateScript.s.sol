// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StakingManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(stakingManagerProxyAddress == 0x25e821b7197B146F7713C3b89B6A4D83516B912d, "stakingManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManager stakingManagerV2Implementation = new StakingManager();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManager stakingManagerV2Instance = StakingManager(stakingManagerProxyAddress);

        vm.stopBroadcast();
    }
}