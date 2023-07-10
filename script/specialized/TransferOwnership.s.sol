// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/MembershipManager.sol";
import "../../src/MembershipNFT.sol";
import "../../src/WeETH.sol";
import "../../src/EETH.sol";
import "../../src/helpers/AddressProvider.sol";
import "../../src/NFTExchange.sol";
import "../../src/LiquidityPool.sol";
import "../../src/RegulationsManager.sol";
import "../../src/EtherFiNodesManager.sol";
import "../../src/ProtocolRevenueManager.sol";
import "../../src/TNFT.sol";
import "../../src/BNFT.sol";
import "../../src/AuctionManager.sol";
import "../../src/StakingManager.sol";

contract TransferOwnership is Script {   

    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        vm.startBroadcast(deployerPrivateKey);

        address auctionManager = addressProvider.getProxyAddress("AuctionManager");
        address stakingManager = addressProvider.getProxyAddress("StakingManager");
        address protocolRevenueManager = addressProvider.getProxyAddress("ProtocolRevenueManager");
        address tnft = addressProvider.getProxyAddress("TNFT");
        address bnft = addressProvider.getProxyAddress("BNFT");
        address etherfiNodesManager = addressProvider.getProxyAddress("EtherFiNodesManager");
        address membershipManager = addressProvider.getProxyAddress("MembershipManager");
        address membershipNFT = addressProvider.getProxyAddress("MembershipNFT");
        address weETH = addressProvider.getProxyAddress("WeETH");
        address eETH = addressProvider.getProxyAddress("EETH");
        address nftExchange = addressProvider.getProxyAddress("NFTExchange");
        address liquidityPool = addressProvider.getProxyAddress("LiquidityPool");
        address regulationsManager = addressProvider.getProxyAddress("RegulationsManager");

        address owner = vm.envAddress("GNOSIS");

        MembershipManager(payable(membershipManager)).transferOwnership(owner); 
        MembershipNFT(membershipNFT).transferOwnership(owner); 
        WeETH(weETH).transferOwnership(owner); 
        EETH(eETH).transferOwnership(owner); 
        NFTExchange(nftExchange).transferOwnership(owner); 
        LiquidityPool(payable(liquidityPool)).transferOwnership(owner); 
        RegulationsManager(regulationsManager).transferOwnership(owner); 
        AuctionManager(auctionManager).transferOwnership(owner); 
        StakingManager(stakingManager).transferOwnership(owner); 
        ProtocolRevenueManager(payable(protocolRevenueManager)).transferOwnership(owner); 
        TNFT(tnft).transferOwnership(owner); 
        BNFT(bnft).transferOwnership(owner); 
        EtherFiNodesManager(payable(etherfiNodesManager)).transferOwnership(owner); 
        addressProvider.setOwner(owner);

        vm.stopBroadcast();
    }
}
