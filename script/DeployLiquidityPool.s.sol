// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployLiquidityPoolScript is Script {
    using Strings for string;

    struct addresses {
        address liquidityPool;
        address eETH;
    }

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        LiquidityPool liquidityPool = new LiquidityPool();
        liquidityPool.initialize();
        EETH eETH = new EETH();
        eETH.initialize(address(liquidityPool));

        liquidityPool.setTokenAddress(address(eETH));

        vm.stopBroadcast();

        addressStruct = addresses({
            liquidityPool: address(liquidityPool),
            eETH: address(eETH)
        });

        writeVersionFile();

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
    }

    function _stringToUint(string memory numString)
        internal
        pure
        returns (uint256)
    {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10**(exp - 1)));
        }
        return val;
    }

    function writeVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine(
            "release/logs/LiquidityPool/version.txt"
        );

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/LiquidityPool/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/LiquidityPool/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\n",
                    Strings.toHexString(addressStruct.liquidityPool),
                    "\n",
                    Strings.toHexString(addressStruct.eETH)
                )
            )
        );
    }
}
