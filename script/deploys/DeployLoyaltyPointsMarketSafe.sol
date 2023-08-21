// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/UUPSProxy.sol";
import "../../src/LoyaltyPointsMarketSafe.sol";
import "../../src/helpers/AddressProvider.sol";

contract DeployLoyaltyPointsMarketSafeScript is Script {

    LPAPoints public lpaPoints;
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");

        addressProvider = AddressProvider(addressProviderAddress);
        
        vm.startBroadcast(deployerPrivateKey);

        lpaPoints = new LPAPoints(1000000000000);

        addressProvider.addContract(address(lpaPoints), "LoyaltyPointsMarketSafe");

        vm.stopBroadcast();
    }
}
