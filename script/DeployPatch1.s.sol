// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployPatch1 is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address eth2DepositContractAddress = vm.envAddress("ETH2_DEPOSIT_CONTRACT_ADDRESS");

        //goerli
        require(stakingManagerProxyAddress == 0x44F5759C47e052E5Cf6495ce236aB0601F1f98fF, "stakingManagerProxyAddress incorrect see .env");
        require(eth2DepositContractAddress == 0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b, "eth2DepositContractAddress incorrect see .env");
        // mainnet
        // require(stakingManagerProxyAddress == 0x25e821b7197B146F7713C3b89B6A4D83516B912d, "stakingManagerProxyAddress incorrect see .env");
        // require(eth2DepositContractAddress == 0x00000000219ab540356cBB839Cbe05303d7705Fa, "eth2DepositContractAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManagerV2 stakingManagerV2Implementation = new StakingManagerV2();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManagerV2 stakingManagerV2Instance = StakingManagerV2(stakingManagerProxyAddress);

        stakingManagerV2Instance.registerEth2DepositContract(eth2DepositContractAddress);

        vm.stopBroadcast();
    }
}
