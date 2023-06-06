// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/ProtocolRevenueManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ProtocolRevenueManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address ProtocolRevenueManagerProxy;
        address ProtocolRevenueManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address ProtocolRevenueManagerProxyAddress = vm.envAddress("PROTOCOL_REVENUE_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(ProtocolRevenueManagerProxyAddress == 0xfE8A8FC74B2fdD3D745AbFc4940DD858BA60696c, "ProtocolRevenueManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        ProtocolRevenueManager ProtocolRevenueManagerInstance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));
        ProtocolRevenueManager ProtocolRevenueManagerV2Implementation = new ProtocolRevenueManager();

        ProtocolRevenueManagerInstance.upgradeTo(address(ProtocolRevenueManagerV2Implementation));
        ProtocolRevenueManager ProtocolRevenueManagerV2Instance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));

        vm.stopBroadcast();
        criticalAddresses = CriticalAddresses({
            ProtocolRevenueManagerProxy: ProtocolRevenueManagerProxyAddress,
            ProtocolRevenueManagerImplementation: address(ProtocolRevenueManagerV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/mainnet/ProtocolRevenueManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/mainnet/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/mainnet/ProtocolRevenueManager/version.txt",
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
                    "release/logs/Upgrades/mainnet/ProtocolRevenueManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.ProtocolRevenueManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.ProtocolRevenueManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}