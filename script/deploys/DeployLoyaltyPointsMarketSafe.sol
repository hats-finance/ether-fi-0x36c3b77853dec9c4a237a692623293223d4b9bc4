// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/UUPSProxy.sol";
import "../../src/LoyaltyPointsMarketSafe.sol";
import "../../src/helpers/AddressProvider.sol";

contract DeployLoyaltyPointsMarketSafeScript is Script {

    LoyaltyPointsMarketSafe public lpaMarketSafe;
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");

        addressProvider = AddressProvider(addressProviderAddress);
        
        vm.startBroadcast(deployerPrivateKey);

        // for us to start off selling 15k points for 0.01 ETH
        // 666666666666 seems like the correct place to start
        lpaMarketSafe = new LoyaltyPointsMarketSafe(666666666666);

        addressProvider.addContract(address(lpaMarketSafe), "LoyaltyPointsMarketSafe");

        vm.stopBroadcast();
    }
}
