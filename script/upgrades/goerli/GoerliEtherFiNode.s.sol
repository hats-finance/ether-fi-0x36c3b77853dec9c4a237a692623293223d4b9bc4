// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/EtherFiNode.sol";
import "../../../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AuctionManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address etherfiNodeImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");

        StakingManager stakingManager = StakingManager(stakingManagerProxyAddress);

        vm.startBroadcast(deployerPrivateKey);

        EtherFiNode etherFiNode = new EtherFiNode();
        stakingManager.upgradeEtherFiNode(address(etherFiNode));

        vm.stopBroadcast();

        criticalAddresses = CriticalAddresses({
            etherfiNodeImplementation: address(etherFiNode)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/EtherFiNode/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/EtherFiNode/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/EtherFiNode/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.etherfiNodeImplementation),
                    "\nOptional Comments: ", 
                    "Upgraded to phase 1.5 contracts"
                )
            )
        );
    }
}