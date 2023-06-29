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

contract UpdateAdmins is Script {   
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address stakingManager = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address etherFiNodesManager = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        address protocolRevenueManager = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");
        address auctionManager = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");
        address liquidityPool = vm.envAddress("LIQUIDITY_POOL_PROXY_ADDRESS");
        address membershipManager = vm.envAddress("MEMBERSHIP_MANAGER_PROXY_ADDRESS");
        address membershipNFT = vm.envAddress("MEMBERSHIP_NFT_PROXY_ADDRESS");
        address nftExchange = vm.envAddress("NFT_EXCHANGE");
        address regulationsManager = vm.envAddress("REGULATIONS_MANAGER_PROXY_ADDRESS");
        address admin = vm.envAddress("ADMIN");

        EtherFiNodesManager(payable(etherFiNodesManager)).updateAdmin(admin); 
        ProtocolRevenueManager(payable(protocolRevenueManager)).updateAdmin(admin); 
        AuctionManager(auctionManager).updateAdmin(admin); 
        StakingManager(stakingManager).updateAdmin(admin); 
        LiquidityPool(payable(liquidityPool)).updateAdmin(admin); 
        MembershipManager(payable(membershipManager)).updateAdmin(admin); 
        MembershipNFT(membershipNFT).updateAdmin(admin); 
        NFTExchange(nftExchange).updateAdmin(admin); 
        RegulationsManager(regulationsManager).updateAdmin(admin); 

        vm.stopBroadcast();
    }
}
