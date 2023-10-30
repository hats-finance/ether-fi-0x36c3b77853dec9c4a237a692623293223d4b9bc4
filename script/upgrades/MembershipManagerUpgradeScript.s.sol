// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/MembershipManager.sol";
import "../../src/helpers/AddressProvider.sol";

contract MembershipManagerUpgrade is Script {
    
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);
        
        address membershipManagerProxy = addressProvider.getContractAddress("MembershipManager");
        address etherFiAdminAddress = addressProvider.getContractAddress("EtherFiAdmin");

        assert(membershipManagerProxy != address(0));
        assert(etherFiAdminAddress != address(0));

        vm.startBroadcast(deployerPrivateKey);

        MembershipManager membershipManagerInstance = MembershipManager(payable(membershipManagerProxy));
        MembershipManager membershipManagerV2Implementation = new MembershipManager();

        membershipManagerInstance.upgradeTo(address(membershipManagerV2Implementation));

        // 0.3 ether is the treshold for ether.fan rewards distribution
        // 183 days (6 months) is required for burn fee waiver
        membershipManagerInstance.initializeOnUpgrade(etherFiAdminAddress, 0.3 ether, 183);
        
        vm.stopBroadcast();
    }
}