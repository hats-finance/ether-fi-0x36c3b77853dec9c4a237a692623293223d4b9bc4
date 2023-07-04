// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/TNFT.sol";
import "../../../src/helpers/AddressProvider.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TNFTUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address TNFTProxy;
        address TNFTImplementation;
    }

    CriticalAddresses criticalAddresses;
    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        address TNFTProxyAddress = addressProvider.getProxyAddress("TNFT");

        require(TNFTProxyAddress == 0x0FE93205B6AdF89F5b9893F393dCf3260cb30bE0, "TNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        TNFT TNFTInstance = TNFT(TNFTProxyAddress);
        TNFT TNFTV2Implementation = new TNFT();

        TNFTInstance.upgradeTo(address(TNFTV2Implementation));
        TNFT TNFTV2Instance = TNFT(TNFTProxyAddress);

        addressProvider.updateContractImplementation("TNFT", address(TNFTV2Implementation));

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/TNFT/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/TNFT/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/TNFT/",
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
                    "tnfts are amazing"
                )
            )
        );
    }
}