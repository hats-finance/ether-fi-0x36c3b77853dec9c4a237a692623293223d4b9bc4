// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/UUPSProxy.sol";
import "../../../src/TVLOracle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployTVLOracleScript is Script {
    using Strings for string;

    /*---- Storage variables ----*/

    TVLOracle public tvlOracle;

    address tvlOracleAddress;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address tvlAggregatorAddress = vm.envAddress("TVL_AGGREGATOR_ADDRESS");

        // Deploy contracts
        tvlOracle = new TVLOracle(tvlAggregatorAddress);
        vm.stopBroadcast();

        tvlOracleAddress = address(tvlOracle);
        writeSuiteVersionFile();
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

    function writeSuiteVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine("release/logs/TVLOracle/goerli/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/TVLOracle/goerli/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/TVLOracle/goerli/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nTVL Oracle: ",
                    Strings.toHexString(tvlOracleAddress)
                )
            )
        );
    }
}
