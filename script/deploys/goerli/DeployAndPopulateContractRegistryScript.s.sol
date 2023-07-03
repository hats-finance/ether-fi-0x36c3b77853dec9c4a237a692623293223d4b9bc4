// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/ContractRegistry.sol";

contract DeployAndPopulateContractRegistry is Script {

    /*---- Storage variables ----*/

    ContractRegistry public contractRegistry;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        contractRegistry = new ContractRegistry();
        console.log(address(contractRegistry));

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

        contractRegistry.addContract(auctionManagerProxyAddress, auctionManagerImplementationAddress, "Auction Manager", 0);
        contractRegistry.addContract(stakingManagerProxyAddress, stakingManagerImplementationAddress, "Staking Manager", 0);
        contractRegistry.addContract(etherFiNodesManagerProxyAddress, etherFiNodesManagerImplementationAddress, "EtherFi Nodes Manager", 0);
        contractRegistry.addContract(protocolRevenueManagerProxy, protocolRevenueManagerImplementation, "Protocol Revenue Manager", 0);
        contractRegistry.addContract(tnftProxy, tnftImplementation, "TNFT", 0);
        contractRegistry.addContract(bnftProxy, bnftImplementation, "BNFT", 0);
        contractRegistry.addContract(address(0), treasury, "Treasury", 0);
        contractRegistry.addContract(address(0), nodeOperatorManagerImplementation, "Node Operator Manager", 0);

        vm.stopBroadcast();
    }
}
