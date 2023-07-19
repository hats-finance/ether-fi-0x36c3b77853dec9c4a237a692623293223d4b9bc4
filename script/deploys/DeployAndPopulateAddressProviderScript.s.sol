// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/helpers/AddressProvider.sol";

contract DeployAndPopulateAddressProvider is Script {

    /*---- Storage variables ----*/

    struct ContractProxyAddresses {
        address auctionManagerProxyAddress;
        address stakingManagerProxyAddress;
        address etherFiNodesManagerProxyAddress;
        address protocolRevenueManagerProxy;
        address tnftProxy;
        address bnftProxy;
    }

    struct ContractImplementationAddresses {
        address auctionManagerImplementationAddress;
        address stakingManagerImplementationAddress;
        address etherFiNodesManagerImplementationAddress;
        address treasury;
        address protocolRevenueManagerImplementation;
        address nodeOperatorManagerImplementation;
        address tnftImplementation;
        address bnftImplementation;
        address etherFiNode;
        address earlyAdopterPool;
    }

    AddressProvider public addressProvider;
    ContractProxyAddresses public contractProxyAddresses;
    ContractImplementationAddresses public contractImplementationAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        addressProvider = new AddressProvider(owner);
        console.log(address(addressProvider));

        /*---- Populate Registry ----*/

        contractProxyAddresses.auctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.etherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.protocolRevenueManagerProxy = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.tnftProxy = vm.envAddress("TNFT_PROXY_ADDRESS");
        contractProxyAddresses.bnftProxy = vm.envAddress("BNFT_PROXY_ADDRESS");

        contractImplementationAddresses.treasury = vm.envAddress("TREASURY_ADDRESS");
        contractImplementationAddresses.nodeOperatorManagerImplementation = vm.envAddress("NODE_OPERATOR_MANAGER_ADDRESS");
        contractImplementationAddresses.etherFiNode = vm.envAddress("ETHERFI_NODE");
        contractImplementationAddresses.earlyAdopterPool = vm.envAddress("EARLY_ADOPTER_POOL");

        addressProvider.addContract(contractProxyAddresses.auctionManagerProxyAddress, "AuctionManager");
        addressProvider.addContract(contractProxyAddresses.stakingManagerProxyAddress, "StakingManager");
        addressProvider.addContract(contractProxyAddresses.etherFiNodesManagerProxyAddress, "EtherFiNodesManager");
        addressProvider.addContract(contractProxyAddresses.protocolRevenueManagerProxy, "ProtocolRevenueManager");
        addressProvider.addContract(contractProxyAddresses.tnftProxy, "TNFT");
        addressProvider.addContract(contractProxyAddresses.bnftProxy, "BNFT");
        addressProvider.addContract(contractImplementationAddresses.treasury, "Treasury");
        addressProvider.addContract(contractImplementationAddresses.nodeOperatorManagerImplementation, "NodeOperatorManager");
        addressProvider.addContract(contractImplementationAddresses.etherFiNode, "EtherFiNode");
        addressProvider.addContract(contractImplementationAddresses.earlyAdopterPool, "EarlyAdopterPool");

        vm.stopBroadcast();
    }
}
