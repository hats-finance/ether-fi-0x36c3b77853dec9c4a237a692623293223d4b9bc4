// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/EtherFiNodesManager.sol";
import "../../src/ProtocolRevenueManager.sol";
import "../../src/AuctionManager.sol";
import "../../src/TNFT.sol";
import "../../src/LiquidityPool.sol";
import "../../src/MembershipManager.sol";
import "../../src/MembershipNFT.sol";
import "../../src/StakingManager.sol";
import "../../src/NFTExchange.sol";
import "../../src/RegulationsManager.sol";
import "../../src/helpers/AddressProvider.sol";

contract UpdateAdmins is Script {   

    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        vm.startBroadcast(deployerPrivateKey);

        address stakingManager = addressProvider.getContractAddress("StakingManager");
        address etherFiNodesManager = addressProvider.getContractAddress("EtherFiNodesManager");
        address protocolRevenueManager = addressProvider.getContractAddress("ProtocolRevenueManager");
        address auctionManager = addressProvider.getContractAddress("AuctionManager");
        address liquidityPool = addressProvider.getContractAddress("LiquidityPool");
        address regulationsManager = addressProvider.getContractAddress("RegulationsManager");
        address membershipNFT = addressProvider.getContractAddress("MembershipNFT");
        address membershipManager = addressProvider.getContractAddress("MembershipManager");
        address nftExchange = addressProvider.getContractAddress("NFTExchange");

        address admin = vm.envAddress("ADMIN");
        EtherFiNodesManager(payable(etherFiNodesManager)).updateAdmin(admin); 
        ProtocolRevenueManager(payable(protocolRevenueManager)).updateAdmin(admin); 
        AuctionManager(auctionManager).updateAdmin(admin); 
        StakingManager(stakingManager).updateAdmin(admin); 
        LiquidityPool(payable(liquidityPool)).updateAdmin(admin);
        RegulationsManager(regulationsManager).updateAdmin(admin);
        MembershipManager(payable(membershipManager)).updateAdmin(admin);
        MembershipNFT(membershipNFT).updateAdmin(admin);
        NFTExchange(nftExchange).updateAdmin(admin);

        vm.stopBroadcast();
    }
}