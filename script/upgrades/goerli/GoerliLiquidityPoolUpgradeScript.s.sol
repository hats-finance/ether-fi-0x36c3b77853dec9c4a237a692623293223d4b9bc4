// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/LiquidityPool.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LiquidityPoolUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address LiquidityPoolProxy;
        address LiquidityPoolImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address LiquidityPoolProxyAddress = vm.envAddress("LIQUIDITY_POOL_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        LiquidityPool LiquidityPoolInstance = LiquidityPool(payable(LiquidityPoolProxyAddress));
        LiquidityPool LiquidityPoolV2Implementation = new LiquidityPool();

        LiquidityPoolInstance.upgradeTo(address(LiquidityPoolV2Implementation));
        LiquidityPool LiquidityPoolV2Instance = LiquidityPool(payable(LiquidityPoolProxyAddress));

        vm.stopBroadcast();
        criticalAddresses = CriticalAddresses({
            LiquidityPoolProxy: LiquidityPoolProxyAddress,
            LiquidityPoolImplementation: address(LiquidityPoolV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/LiquidityPool/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/LiquidityPool/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
    

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/LiquidityPool/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.LiquidityPoolProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.LiquidityPoolImplementation),
                    "\nOptional Comments: ", 
                    "Upgraded LP with Sykos latest PR"
                )
            )
        );
    }
}