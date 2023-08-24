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

        addressProvider.removeContract("EtherFiOracle");

        etherFiOracleImplementation = new EtherFiOracle();
        etherFiOracleProxy = new UUPSProxy(address(etherFiOracleImplementation), "");
        etherFiOracleInstance = EtherFiOracle(payable(etherFiOracleProxy));

        etherFiOracleInstance.initialize(1, 128, 32, 12, beacon_genesis_time);
        // etherFiOracleInstance.initialize(2, 7200, 12, beacon_genesis_time);
        // 96 slots = 19.2 mins, 7200 slots = 225 epochs = 1day

        etherFiOracleInstance.addCommitteeMember(address(0xD0d7F8a5a86d8271ff87ff24145Cf40CEa9F7A39));
        etherFiOracleInstance.addCommitteeMember(address(0x601B37004f2A6B535a6cfBace0f88D2d534aCcD8));

        addressProvider.addContract(address(etherFiOracleProxy), "EtherFiOracle");

        vm.stopBroadcast();
    }
}