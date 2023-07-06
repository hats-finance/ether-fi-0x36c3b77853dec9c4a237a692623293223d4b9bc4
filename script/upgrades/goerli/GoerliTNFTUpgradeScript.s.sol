// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/TNFT.sol";
import "../../../src/helpers/AddressProvider.sol";

contract TNFTUpgrade is Script {
   
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        address TNFTProxyAddress = addressProvider.getProxyAddress("TNFT");

        require(TNFTProxyAddress == 0x0FE93205B6AdF89F5b9893F393dCf3260cb30bE0, "TNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        TNFT TNFTInstance = TNFT(TNFTProxyAddress);
        TNFT TNFTV2Implementation = new TNFT();

        TNFTInstance.upgradeTo(address(TNFTV2Implementation));

        addressProvider.updateContractImplementation("TNFT", address(TNFTV2Implementation));

        vm.stopBroadcast();
    }
}