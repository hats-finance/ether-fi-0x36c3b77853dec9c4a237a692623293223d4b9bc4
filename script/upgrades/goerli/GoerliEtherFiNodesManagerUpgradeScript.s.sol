// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/EtherFiNodesManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract EtherFiNodesManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address EtherFiNodesManagerProxy;
        address EtherFiNodesManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address EtherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");

        require(EtherFiNodesManagerProxyAddress == 0xB914b281260222c6C118FEBD78d5dbf4fD419Ffb, "EtherFiNodesManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        EtherFiNodesManager EtherFiNodesManagerInstance = EtherFiNodesManager(payable(EtherFiNodesManagerProxyAddress));
        EtherFiNodesManager EtherFiNodesManagerV2Implementation = new EtherFiNodesManager();

        EtherFiNodesManagerInstance.upgradeTo(address(EtherFiNodesManagerV2Implementation));
        EtherFiNodesManager EtherFiNodesManagerV2Instance = EtherFiNodesManager(payable(EtherFiNodesManagerProxyAddress));

        vm.stopBroadcast();
   
        criticalAddresses = CriticalAddresses({
            EtherFiNodesManagerProxy: EtherFiNodesManagerProxyAddress,
            EtherFiNodesManagerImplementation: address(EtherFiNodesManagerV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/EtherFiNodesManager/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/EtherFiNodesManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        
        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/EtherFiNodesManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.EtherFiNodesManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.EtherFiNodesManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment here"
                )
            )
        );
    }
}