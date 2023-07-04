// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/NFTExchange.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GoerliNFTExchangeUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address nftExchangeProxy;
        address nftExchangeImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address nftExchangeProxyAddress = vm.envAddress("NFT_EXCHANGE");
       
        vm.startBroadcast(deployerPrivateKey);

        NFTExchange nftExchangeInstance = NFTExchange(nftExchangeProxyAddress);
        NFTExchange nftExchangeV2Implementation = new NFTExchange();

        nftExchangeInstance.upgradeTo(address(nftExchangeV2Implementation));
        NFTExchange nftExchangeV2Instance = NFTExchange(nftExchangeProxyAddress);

        vm.stopBroadcast();

        criticalAddresses = CriticalAddresses({
            nftExchangeProxy: nftExchangeProxyAddress,
            nftExchangeImplementation: address(nftExchangeV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/NFTExchange/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/NFTExchange/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/NFTExchange/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.nftExchangeProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.nftExchangeImplementation),
                    "\nOptional Comments: ", 
                    "Upgraded to phase 1.5 contracts"
                )
            )
        );
    }
}