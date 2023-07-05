// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/AuctionManager.sol";
import "../../../src/helpers/AddressProvider.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AuctionManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address auctionManagerProxy;
        address auctionManagerImplementation;
    }

    CriticalAddresses criticalAddresses;
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);
        
        address AuctionManagerProxyAddress = addressProvider.getProxyAddress("AuctionManager");

        require(AuctionManagerProxyAddress == 0xAB5768448499250Bda8a29F35A3eE47FAD69Eb3C, "AuctionManagerProxyAddress incorrect see .env");
       
        vm.startBroadcast(deployerPrivateKey);

        AuctionManager AuctionManagerInstance = AuctionManager(AuctionManagerProxyAddress);
        AuctionManager AuctionManagerV2Implementation = new AuctionManager();

        AuctionManagerInstance.upgradeTo(address(AuctionManagerV2Implementation));
        AuctionManager AuctionManagerV2Instance = AuctionManager(AuctionManagerProxyAddress);

        addressProvider.updateContractImplementation("AuctionManager", address(AuctionManagerV2Implementation));

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/AuctionManager/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/AuctionManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/AuctionManager/",
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
                    "Upgraded to phase 1.5 contracts"
                )
            )
        );
    }
}