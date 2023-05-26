// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/AuctionManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AuctionManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address auctionManagerProxy;
        address auctionManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address AuctionManagerProxyAddress = vm.envAddress("AUCTION_MANAGER_PROXY_ADDRESS");

        require(AuctionManagerProxyAddress == 0x00C452aFFee3a17d9Cecc1Bcd2B8d5C7635C4CB9, "AuctionManagerProxyAddress incorrect see .env");
        
        vm.startBroadcast(deployerPrivateKey);

        AuctionManager AuctionManagerInstance = AuctionManager(AuctionManagerProxyAddress);
        AuctionManager AuctionManagerV2Implementation = new AuctionManager();

        AuctionManagerInstance.upgradeTo(address(AuctionManagerV2Implementation));
        AuctionManager AuctionManagerV2Instance = AuctionManager(AuctionManagerProxyAddress);

        vm.stopBroadcast();

        criticalAddresses = CriticalAddresses({
            auctionManagerProxy: AuctionManagerProxyAddress,
            auctionManagerImplementation: address(AuctionManagerV2Implementation)
        });

        writeUpgradeVersionFile();
    }

    function _stringToUint(
        string memory numString
    ) internal pure returns (uint256) {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10 ** (exp - 1)));
        }
        return val;
    }

    function writeUpgradeVersionFile() internal {
        // Read Local Current version
        string memory localVersionString = vm.readLine("release/logs/Upgrades/mainnet/AuctionManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/mainnet/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/mainnet/AuctionManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        vm.writeFile(
            "release/logs/Upgrades/mainnet/version.txt",
            string(abi.encodePacked(Strings.toString(globalVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/mainnet/AuctionManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.auctionManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.auctionManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}