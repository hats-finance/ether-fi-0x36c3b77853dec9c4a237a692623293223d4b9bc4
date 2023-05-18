// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/RegulationsManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RegulationsManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address RegulationsManagerProxy;
        address RegulationsManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address RegulationsManagerProxyAddress = vm.envAddress("REGULATIONS_MANAGER_PROXY_ADDRESS");

        // mainnet
        //require(RegulationsManagerProxyAddress ==, "RegulationsManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        RegulationsManager RegulationsManagerInstance = RegulationsManager(RegulationsManagerProxyAddress);
        RegulationsManager RegulationsManagerV2Implementation = new RegulationsManager();

        RegulationsManagerInstance.upgradeTo(address(RegulationsManagerV2Implementation));
        RegulationsManager RegulationsManagerV2Instance = RegulationsManager(RegulationsManagerProxyAddress);

        vm.stopBroadcast();
        criticalAddresses = CriticalAddresses({
            RegulationsManagerProxy: RegulationsManagerProxyAddress,
            RegulationsManagerImplementation: address(RegulationsManagerV2Implementation)
        });

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/RegulationsManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/goerli/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/RegulationsManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        vm.writeFile(
            "release/logs/Upgrades/goerli/version.txt",
            string(abi.encodePacked(Strings.toString(globalVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/RegulationsManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.RegulationsManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.RegulationsManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}