// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/EarlyAdopterPool.sol";
import "../test/TestERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployEarlyAdopterPoolScript is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TestERC20 rEth = new TestERC20("Rocket Pool Eth", "rEth");
        TestERC20 wstEth = new TestERC20("Wrapped Staked Pool Eth", "wstEth");
        TestERC20 sfrxEth = new TestERC20("Staked Frax Eth", "sfrxEth");
        TestERC20 cbEth = new TestERC20("Coinbase Eth", "cbEth");

        EarlyAdopterPool earlyAdopterPool = new EarlyAdopterPool(
            address(rEth),
            address(wstEth),
            address(sfrxEth),
            address(cbEth)
        );

        vm.stopBroadcast();

        // Sets the variables to be wriiten to contract addresses.txt
        string memory earlyAdopterPoolAddress = Strings.toHexString(
            address(earlyAdopterPool)
        );

        // Declare version Var
        uint256 version;

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
        string memory versionPath = "release/logs/earlyAdopterPool/version.txt";

        // Read Current version
        string memory versionString = vm.readLine(versionPath);

        // Cast string to uint256
        version = _stringToUint(versionString);

        version++;

        // Declares the incremented version to be written to version.txt file
        string memory versionData = string(
            abi.encodePacked(Strings.toString(version))
        );

        // Overwrites the version.txt file with incremented version
        vm.writeFile(versionPath, versionData);

        // Sets the path for the release file using the incremented version var
        string memory releasePath = string(
            abi.encodePacked(
                "release/logs/earlyAdopterPool/",
                Strings.toString(version),
                ".release"
            )
        );

        // Concatenates data to be written to X.release file
        string memory writeData = string(
            abi.encodePacked(
                "Version: ",
                Strings.toString(version),
                "\n",
                "Early Adopter Pool Contract Address: ",
                earlyAdopterPoolAddress
            )
        );

        // Writes the data to .release file
        vm.writeFile(releasePath, writeData);
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
}
