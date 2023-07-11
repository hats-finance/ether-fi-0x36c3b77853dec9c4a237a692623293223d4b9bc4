// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/EETH.sol";
import "../../src/WeETH.sol";
import "../../src/LiquidityPool.sol";
import "../../src/MembershipManager.sol";
import "../../src/NFTExchange.sol";
import "../../src/RegulationsManager.sol";
import "../../src/helpers/AddressProvider.sol";

contract UpdateAddressProviderImplementationAddresses is Script {   

    AddressProvider public addressProvider;

    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        vm.startBroadcast(deployerPrivateKey);

        address eETHImplementationAddress = vm.envAddress("EETH_IMPLEMENTATION_ADDRESS");
        address liquidityPoolImplementationAddress = vm.envAddress("LIQUIDITY_POOL_IMPLEMENTATION_ADDRESS");
        address membershipManagerImplementationAddress = vm.envAddress("MEMBERSHIP_MANAGER_IMPLEMENTATION_ADDRESS");
        address nftExchangeImplementationAddress = vm.envAddress("NFT_IMPLEMENTATION_EXCHANGE");
        address regulationsManagerImplementationAddress = vm.envAddress("REGULATIONS_MANAGER_IMPLEMENTATION_ADDRESS");
        address weETHImplementationAddress = vm.envAddress("WEETH_IMPLEMENTATION_ADDRESS");

        address eETH = addressProvider.getProxyAddress("EETH");
        address liquidityPool = addressProvider.getProxyAddress("LiquidityPool");
        address membershipManager = addressProvider.getProxyAddress("MembershipManager");
        address nftExchange = addressProvider.getProxyAddress("NFTExchange");
        address regulationsManager = addressProvider.getProxyAddress("RegulationsManager");
        address weETH = addressProvider.getProxyAddress("WeETH");

        addressProvider.updateContractImplementation("EETH", eETHImplementationAddress);
        addressProvider.updateContractImplementation("LiquidityPool", liquidityPoolImplementationAddress);
        addressProvider.updateContractImplementation("MembershipManager", membershipManagerImplementationAddress);
        addressProvider.updateContractImplementation("NFTExchange", nftExchangeImplementationAddress);
        addressProvider.updateContractImplementation("RegulationsManager", regulationsManagerImplementationAddress);
        addressProvider.updateContractImplementation("WeETH", weETHImplementationAddress);

        vm.stopBroadcast();
    }
}