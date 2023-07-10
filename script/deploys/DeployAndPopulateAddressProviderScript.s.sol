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
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast(deployerPrivateKey);

        addressProvider = new AddressProvider{salt: 0x0}(owner);
        console.log(address(addressProvider));

        /*---- Populate Registry ----*/

        contractProxyAddresses.auctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.etherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.protocolRevenueManagerProxy = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");
        contractProxyAddresses.tnftProxy = vm.envAddress("TNFT_PROXY_ADDRESS");
        contractProxyAddresses.bnftProxy = vm.envAddress("BNFT_PROXY_ADDRESS");

        contractImplementationAddresses.auctionManagerImplementationAddress = vm.envAddress("AUCTION_MANAGER_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.stakingManagerImplementationAddress = vm.envAddress("STAKING_MANAGER_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.etherFiNodesManagerImplementationAddress = vm.envAddress("ETHERFI_NODES_MANAGER_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.treasury = vm.envAddress("TREASURY_ADDRESS");
        contractImplementationAddresses.protocolRevenueManagerImplementation = vm.envAddress("PROTOCOL_REVENUE_MANAGER_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.nodeOperatorManagerImplementation = vm.envAddress("NODE_OPERATOR_MANAGER_ADDRESS");
        contractImplementationAddresses.tnftImplementation = vm.envAddress("TNFT_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.bnftImplementation = vm.envAddress("BNFT_IMPLEMENTATION_ADDRESS");
        contractImplementationAddresses.etherFiNode = vm.envAddress("ETHERFI_NODE");
        contractImplementationAddresses.earlyAdopterPool = vm.envAddress("EARLY_ADOPTER_POOL");

        addressProvider.addContract(contractProxyAddresses.auctionManagerProxyAddress, contractImplementationAddresses.auctionManagerImplementationAddress, "AuctionManager");
        addressProvider.addContract(contractProxyAddresses.stakingManagerProxyAddress, contractImplementationAddresses.stakingManagerImplementationAddress, "StakingManager");
        addressProvider.addContract(contractProxyAddresses.etherFiNodesManagerProxyAddress, contractImplementationAddresses.etherFiNodesManagerImplementationAddress, "EtherFiNodesManager");
        addressProvider.addContract(contractProxyAddresses.protocolRevenueManagerProxy, contractImplementationAddresses.protocolRevenueManagerImplementation, "ProtocolRevenueManager");
        addressProvider.addContract(contractProxyAddresses.tnftProxy, contractImplementationAddresses.tnftImplementation, "TNFT");
        addressProvider.addContract(contractProxyAddresses.bnftProxy, contractImplementationAddresses.bnftImplementation, "BNFT");
        addressProvider.addContract(address(0), contractImplementationAddresses.treasury, "Treasury");
        addressProvider.addContract(address(0), contractImplementationAddresses.nodeOperatorManagerImplementation, "NodeOperatorManager");
        addressProvider.addContract(address(0), contractImplementationAddresses.etherFiNode, "EtherFiNode");
        addressProvider.addContract(address(0), contractImplementationAddresses.earlyAdopterPool, "EarlyAdopterPool");

        vm.stopBroadcast();
    }
}
