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

        // mainnet
        require(EtherFiNodesManagerProxyAddress == 0x8B71140AD2e5d1E7018d2a7f8a288BD3CD38916F, "EtherFiNodesManagerProxyAddress incorrect see .env");

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/EtherFiNodesManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/EtherFiNodesManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        vm.writeFile(
            "release/logs/Upgrades/version.txt",
            string(abi.encodePacked(Strings.toString(globalVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/EtherFiNodesManager/",
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
                    "The current 'proccessNodeExit' function does not take into account duplicate exits, we fixed this by adding a require to make sure the validator is in the LIVE phase"
                )
            )
        );
    }
}