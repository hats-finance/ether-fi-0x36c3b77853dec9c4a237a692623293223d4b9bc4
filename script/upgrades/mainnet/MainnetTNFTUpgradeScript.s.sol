// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/TNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TNFTUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address TNFTProxy;
        address TNFTImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address TNFTProxyAddress = vm.envAddress("TNFT_PROXY_ADDRESS");

        require(TNFTProxyAddress == 0x7B5ae07E2AF1C861BcC4736D23f5f66A61E0cA5e, "TNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        TNFT TNFTInstance = TNFT(TNFTProxyAddress);
        TNFT TNFTV2Implementation = new TNFT();

        TNFTInstance.upgradeTo(address(TNFTV2Implementation));
        TNFT TNFTV2Instance = TNFT(TNFTProxyAddress);

        vm.stopBroadcast();
        
        criticalAddresses = CriticalAddresses({
            TNFTProxy: TNFTProxyAddress,
            TNFTImplementation: address(TNFTV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/mainnet/TNFT/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/mainnet/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/mainnet/TNFT/version.txt",
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
                    "release/logs/Upgrades/mainnet/TNFT/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.TNFTProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.TNFTImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}