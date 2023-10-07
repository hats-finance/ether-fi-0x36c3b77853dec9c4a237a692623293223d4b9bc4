// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployPatch1 is Script {
    using Strings for string;

    StakingManager public stakingManagerV2Implementation;
    StakingManager public stakingManagerInstance;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address eth2DepositContractAddress = vm.envAddress("ETH2_DEPOSIT_CONTRACT_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManager stakingManagerV2Implementation = new StakingManager();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManager stakingManagerV2Instance = StakingManager(stakingManagerProxyAddress);

        stakingManagerV2Instance.registerEth2DepositContract(eth2DepositContractAddress);

        vm.stopBroadcast();
    }
}
