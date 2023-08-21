// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/UUPSProxy.sol";
import "../../src/EtherFiOracle.sol";
import "../../src/helpers/AddressProvider.sol";
import "../../src/UUPSProxy.sol";

contract DeployOracleScript is Script {
    UUPSProxy public etherFiOracleProxy;
    EtherFiOracle public etherFiOracleInstance;
    EtherFiOracle public etherFiOracleImplementation;
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");    
        uint32 beacon_genesis_time = uint32(vm.envUint("BEACON_GENESIS_TIME"));
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);
        
        vm.startBroadcast(deployerPrivateKey);

        etherFiOracleImplementation = new EtherFiOracle();
        etherFiOracleProxy = new UUPSProxy(address(etherFiOracleImplementation), "");
        etherFiOracleInstance = EtherFiOracle(payable(etherFiOracleProxy));
        etherFiOracleInstance.initialize(2, 32, 12, beacon_genesis_time);

        etherFiOracleInstance.setOracleReportPeriod(75); // 75 slots = 15 mins
        // etherFiOracleInstance.setOracleReportPeriod(7200); // 7200 slots = 225 epochs = 1 day

        addressProvider.addContract(address(etherFiOracleProxy), "EtherFiOracle");

        vm.stopBroadcast();
    }
}