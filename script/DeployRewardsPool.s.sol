// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/RewardsPool.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployRewardsPoolScript is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        RewardsPool rewardsPool = new RewardsPool(
            0xae78736Cd615f374D3085123A210448E74Fc6393,
            0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84,
            0x5E8422345238F34275888049021821E8E08CAa1f
        );

        vm.stopBroadcast();

        // Sets the variables to be wriiten to contract addresses.txt
        string memory rewardsPoolAddress = Strings.toHexString(
            address(rewardsPool)
        );

        // Declare version Var
        uint256 version;

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
        string memory versionPath = "release/logs/rewardsPool/version.txt";

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
                "release/logs/rewardsPool/",
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
                "Deposit Pool Contract Address: ",
                rewardsPoolAddress
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
