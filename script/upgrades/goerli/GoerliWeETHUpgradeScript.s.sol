// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/WeETH.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract WeEthUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address WeETHProxy;
        address WeETHImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address weEthProxyAddress = vm.envAddress("WeETH_PROXY_ADDRESS");

        // mainnet
        //require(weEthProxyAddress == , "weEthProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        WeETH weEthInstance = WeETH(weEthProxyAddress);
        WeETH weEthV2Implementation = new WeETH();

        weEthInstance.upgradeTo(address(weEthV2Implementation));
        WeETH weEthV2Instance = WeETH(weEthProxyAddress);

        vm.stopBroadcast();
        
        criticalAddresses = CriticalAddresses({
            WeETHProxy: weEthProxyAddress,
            WeETHImplementation: address(weEthV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/WeETH/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/goerli/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/WeETH/version.txt",
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
                    "release/logs/Upgrades/goerli/WeETH/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.WeETHProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.WeETHImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}