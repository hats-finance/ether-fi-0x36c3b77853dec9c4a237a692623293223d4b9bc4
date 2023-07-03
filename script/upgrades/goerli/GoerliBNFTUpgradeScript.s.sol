// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/BNFT.sol";
import "../../../src/ContractRegistry.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BNFTUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address BNFTProxy;
        address BNFTImplementation;
    }

    CriticalAddresses criticalAddresses;
    ContractRegistry public contractRegistry;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address contractRegistryAddress = vm.envAddress("CONTRACT_REGISTRY");
        contractRegistry = ContractRegistry(contractRegistryAddress);
        
        address BNFTProxyAddress = contractRegistry.getProxyAddress("BNFT");

        require(BNFTProxyAddress == 0x9F230a10e78343829888924B4c8CeA4F082586f9, "BNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        BNFT BNFTInstance = BNFT(BNFTProxyAddress);
        BNFT BNFTV2Implementation = new BNFT();

        BNFTInstance.upgradeTo(address(BNFTV2Implementation));
        BNFT BNFTV2Instance = BNFT(BNFTProxyAddress);

        contractRegistry.updateContractImplementation(5, address(BNFTV2Implementation));

        vm.stopBroadcast();

        criticalAddresses = CriticalAddresses({
            BNFTProxy: BNFTProxyAddress,
            BNFTImplementation: address(BNFTV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/BNFT/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/BNFT/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/BNFT/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.BNFTProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.BNFTImplementation),
                    "\nOptional Comments: ", 
                    "bnfts are dope"
                )
            )
        );
    }
}