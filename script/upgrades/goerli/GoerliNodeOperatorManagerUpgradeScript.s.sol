// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/NodeOperatorManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NodeOperatorManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address NodeOperatorManagerProxy;
        address NodeOperatorManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address NodeOperatorManagerProxyAddress = vm.envAddress("NODE_OPERATOR_MANAGER_PROXY_ADDRESS");

        // mainnet
        //require(NodeOperatorManagerProxyAddress == , "NodeOperatorManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        NodeOperatorManager NodeOperatorManagerInstance = NodeOperatorManager(NodeOperatorManagerProxyAddress);
        NodeOperatorManager NodeOperatorManagerV2Implementation = new NodeOperatorManager();

        NodeOperatorManagerInstance.upgradeTo(address(NodeOperatorManagerV2Implementation));
        NodeOperatorManager NodeOperatorManagerV2Instance = NodeOperatorManager(NodeOperatorManagerProxyAddress);

        vm.stopBroadcast();
        
        criticalAddresses = CriticalAddresses({
            NodeOperatorManagerProxy: NodeOperatorManagerProxyAddress,
            NodeOperatorManagerImplementation: address(NodeOperatorManagerV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/NodeOperatorManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/goerli/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/NodeOperatorManager/version.txt",
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
                    "release/logs/Upgrades/goerli/NodeOperatorManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.NodeOperatorManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.NodeOperatorManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}