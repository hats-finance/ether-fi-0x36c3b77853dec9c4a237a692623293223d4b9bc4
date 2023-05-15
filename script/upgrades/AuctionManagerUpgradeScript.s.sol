// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/AuctionManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AuctionManagerUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address AuctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(AuctionManagerProxyAddress == 0x00C452aFFee3a17d9Cecc1Bcd2B8d5C7635C4CB9, "AuctionManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        AuctionManager AuctionManagerInstance = AuctionManager(AuctionManagerProxyAddress);
        AuctionManager AuctionManagerV2Implementation = new AuctionManager();

        AuctionManagerInstance.upgradeTo(address(AuctionManagerV2Implementation));
        AuctionManager AuctionManagerV2Instance = AuctionManager(AuctionManagerProxyAddress);

        vm.stopBroadcast();
    }
}