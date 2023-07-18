// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/helpers/AddressProvider.sol";

contract DeployAndPopulateAddressProvider is Script {

    /*---- Storage variables ----*/

    struct ContractAddresses {
        address auctionManagerAddress;
        address stakingManagerAddress;
        address etherFiNodesManagerAddress;
        address protocolRevenueManager;
        address tnft;
        address bnft;
        address eETH;
        address liquidityPool;
        address membershipManager;
        address membershipNFT;
        address nftExchange;
        address regulationsManager;
        address weETH;
        address treasury;
        address nodeOperatorManager;
        address etherFiNode;
        address earlyAdopterPool;
    }

    AddressProvider public addressProvider;
    ContractAddresses public contractAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("DEPLOYER");
        vm.startBroadcast(deployerPrivateKey);

        addressProvider = new AddressProvider(owner);
        console.log(address(addressProvider));

        /*---- Populate Registry ----*/

        contractAddresses.auctionManagerAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");
        contractAddresses.stakingManagerAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        contractAddresses.etherFiNodesManagerAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        contractAddresses.protocolRevenueManager = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");
        contractAddresses.tnft = vm.envAddress("TNFT_PROXY_ADDRESS");
        contractAddresses.bnft = vm.envAddress("BNFT_PROXY_ADDRESS");
        contractAddresses.treasury = vm.envAddress("TREASURY_ADDRESS");
        contractAddresses.nodeOperatorManagerImplementation = vm.envAddress("NODE_OPERATOR_MANAGER_ADDRESS");
        contractAddresses.etherFiNode = vm.envAddress("ETHERFI_NODE");
        contractAddresses.earlyAdopterPool = vm.envAddress("EARLY_ADOPTER_POOL");
        contractAddresses.eETH = vm.envAddress("EETH_PROXY_ADDRESS");
        contractAddresses.liquidityPool = vm.envAddress("LIQUIDITY_POOL_PROXY_ADDRESS");
        contractAddresses.membershipManager = vm.envAddress("MEMBERSHIP_MANAGER_PROXY_ADDRESS");
        contractAddresses.membershipNFT = vm.envAddress("MEMBERSHIP_NFT_PROXY_ADDRESS");
        contractAddresses.nftExchange = vm.envAddress("NFT_EXCHANGE");
        contractAddresses.regulationsManager = vm.envAddress("REGULATIONS_MANAGER_PROXY_ADDRESS");
        contractAddresses.weETH = vm.envAddress("WEETH_PROXY_ADDRESS");

        addressProvider.addContract(contractAddresses.auctionManagerAddress, "AuctionManager");
        addressProvider.addContract(contractAddresses.stakingManagerAddress, "StakingManager");
        addressProvider.addContract(contractAddresses.etherFiNodesManagerAddress, "EtherFiNodesManager");
        addressProvider.addContract(contractAddresses.protocolRevenueManager, "ProtocolRevenueManager");
        addressProvider.addContract(contractAddresses.tnft, "TNFT");
        addressProvider.addContract(contractAddresses.bnft, "BNFT");
        addressProvider.addContract(contractAddresses.treasury, "Treasury");
        addressProvider.addContract(contractAddresses.nodeOperatorManagerImplementation, "NodeOperatorManager");
        addressProvider.addContract(contractAddresses.etherFiNode, "EtherFiNode");
        addressProvider.addContract(contractAddresses.earlyAdopterPool, "EarlyAdopterPool");
        addressProvider.addContract(contractAddresses.eETH, "EETH");
        addressProvider.addContract(contractAddresses.liquidityPool, "LiquidityPool");
        addressProvider.addContract(contractAddresses.membershipManager, "MembershipManager");
        addressProvider.addContract(contractAddresses.membershipNFT, "MembershipNFT");
        addressProvider.addContract(contractAddresses.nftExchange, "NFTExchange");
        addressProvider.addContract(contractAddresses.regulationsManager, "RegulationsManager");
        addressProvider.addContract(contractAddresses.weETH, "WeETH");

        vm.stopBroadcast();
    }
}
