// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployPatch1 is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("stakingManagerProxyAddress");
        address eth2DepositContractAddress = vm.envAddress("eth2DepositContractAddress");

        require(stakingManagerProxyAddress == 0x25e821b7197B146F7713C3b89B6A4D83516B912d, "wrong address");
        require(eth2DepositContractAddress == 0x00000000219ab540356cBB839Cbe05303d7705Fa, "wrong address");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManagerV2 stakingManagerV2Implementation = new StakingManagerV2();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManagerV2 stakingManagerV2Instance = StakingManagerV2(stakingManagerProxyAddress);

        stakingManagerV2Instance.registerEth2DepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa);

        vm.stopBroadcast();
    }
}
