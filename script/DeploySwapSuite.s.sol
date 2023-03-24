// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../test/TestERC20.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/ClaimReceiverPool.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeploySwapSuiteScript is Script {
    using Strings for string;

    struct addresses {
        address earlyAdopterPool;
        address convPool;
    }

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TestERC20 rETH = new TestERC20("Test Rocket Eth", "trETH");
        TestERC20 wstETH = new TestERC20("Test wrapped stake Eth", "twstETH");
        TestERC20 sfrxETH = new TestERC20("Test staked frax Eth", "tsfrxETH");
        TestERC20 cbETH = new TestERC20("Test coinbase Eth", "tcbETH");

        EarlyAdopterPool earlyAdopterPool = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxETH),
            address(cbETH)
        );

        ClaimReceiverPool convPool = new ClaimReceiverPool(
            address(earlyAdopterPool),
            address(rETH),
            address(wstETH),
            address(sfrxETH),
            address(cbETH)
        );

        vm.stopBroadcast();

        addressStruct = addresses({
            earlyAdopterPool: address(earlyAdopterPool),
            convPool: address(convPool)
        });

        writeVersionFile();

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
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

    function writeVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine("release/logs/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nEAP: ",
                    Strings.toHexString(addressStruct.earlyAdopterPool),
                    "\nReceiverPool: ",
                    Strings.toHexString(addressStruct.convPool)
                )
            )
        );
    }
}
