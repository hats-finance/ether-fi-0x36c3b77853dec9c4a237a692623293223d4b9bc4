// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/helpers/AddressProvider.sol";

contract DeployAndPopulateAddressProvider is Script {

    /*---- Storage variables ----*/

    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("ADMIN");
        vm.startBroadcast(deployerPrivateKey);

        addressProvider = new AddressProvider{salt: 0x6d61676963206d6f6e657920676f207570000000000000000000000000000000}(owner);
        console.log(address(addressProvider));

        /*---- Populate Registry ----*/

        address auctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address etherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        address protocolRevenueManagerProxy = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");
        address tnftProxy = vm.envAddress("TNFT_PROXY_ADDRESS");
        address bnftProxy = vm.envAddress("BNFT_PROXY_ADDRESS");

        address auctionManagerImplementationAddress = vm.envAddress("AUCTION_MANAGER_IMPLEMENTATION_ADDRESS");
        address stakingManagerImplementationAddress = vm.envAddress("STAKING_MANAGER_IMPLEMENTATION_ADDRESS");
        address etherFiNodesManagerImplementationAddress = vm.envAddress("ETHERFI_NODES_MANAGER_IMPLEMENTATION_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address protocolRevenueManagerImplementation = vm.envAddress("PROTOCOL_REVENUE_MANAGER_IMPLEMENTATION_ADDRESS");
        address nodeOperatorManagerImplementation = vm.envAddress("NODE_OPERATOR_MANAGER_ADDRESS");
        address tnftImplementation = vm.envAddress("TNFT_IMPLEMENTATION_ADDRESS");
        address bnftImplementation = vm.envAddress("BNFT_IMPLEMENTATION_ADDRESS");

        addressProvider.addContract(auctionManagerProxyAddress, auctionManagerImplementationAddress, "AuctionManager");
        addressProvider.addContract(stakingManagerProxyAddress, stakingManagerImplementationAddress, "StakingManager");
        addressProvider.addContract(etherFiNodesManagerProxyAddress, etherFiNodesManagerImplementationAddress, "EtherFiNodesManager");
        addressProvider.addContract(protocolRevenueManagerProxy, protocolRevenueManagerImplementation, "ProtocolRevenueManager");
        addressProvider.addContract(tnftProxy, tnftImplementation, "TNFT");
        addressProvider.addContract(bnftProxy, bnftImplementation, "BNFT");
        addressProvider.addContract(address(0), treasury, "Treasury");
        addressProvider.addContract(address(0), nodeOperatorManagerImplementation, "NodeOperatorManager");

        vm.stopBroadcast();
    }
}
