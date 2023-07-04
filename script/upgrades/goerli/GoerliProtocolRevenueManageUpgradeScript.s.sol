// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/ProtocolRevenueManager.sol";
import "../../../src/helpers/GoerliAddressProvider.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ProtocolRevenueManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address ProtocolRevenueManagerProxy;
        address ProtocolRevenueManagerImplementation;
    }

    CriticalAddresses criticalAddresses;
    GoerliAddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = GoerliAddressProvider(addressProviderAddress);

        address ProtocolRevenueManagerProxyAddress = addressProvider.getProxyAddress("ProtocolRevenueManager");

        require(ProtocolRevenueManagerProxyAddress == 0xFafcc0041100a80Fce3bD52825A36F73Bf9Fd93a, "ProtocolRevenueManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        ProtocolRevenueManager ProtocolRevenueManagerInstance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));
        ProtocolRevenueManager ProtocolRevenueManagerV2Implementation = new ProtocolRevenueManager();

        ProtocolRevenueManagerInstance.upgradeTo(address(ProtocolRevenueManagerV2Implementation));
        ProtocolRevenueManager ProtocolRevenueManagerV2Instance = ProtocolRevenueManager(payable(ProtocolRevenueManagerProxyAddress));
        
        addressProvider.updateContractImplementation(3, address(ProtocolRevenueManagerV2Implementation));

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/ProtocolRevenueManager/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/ProtocolRevenueManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/ProtocolRevenueManager/",
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
                    "love that protocol revenue manager"
                )
            )
        );
    }
}