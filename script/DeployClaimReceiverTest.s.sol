// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../test/TestERC20.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/ClaimReceiverPool.sol";
import "../src/ScoreManager.sol";
import "../src/RegulationsManager.sol";
import "../lib/murky/src/Merkle.sol";
import "../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployClaimReceiverTestScript is Script {
    using Strings for string;

    struct addresses {
        address earlyAdopterPool;
        address receiverPool;
    }

    ClaimReceiverPool public claimReceiverPoolImplementation;
    ClaimReceiverPool public claimReceiverPoolInstance;

    ScoreManager public scoreManagerInstance;
    ScoreManager public scoreManagerImplementation;

    RegulationsManager public regulationsManagerInstance;
    RegulationsManager public regulationsManagerImplementation;

    UUPSProxy public claimReceiverPoolProxy;
    UUPSProxy public scoreManagerProxy;
    UUPSProxy public regulationsManagerProxy;

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        TestERC20 rETH = new TestERC20("Test Rocket Eth", "trETH");
        TestERC20 wstETH = new TestERC20("Test wrapped stake Eth", "twstETH");
        TestERC20 sfrxETH = new TestERC20("Test staked frax Eth", "tsfrxETH");
        TestERC20 cbETH = new TestERC20("Test coinbase Eth", "tcbETH");

        scoreManagerImplementation = new ScoreManager();
        scoreManagerProxy = new UUPSProxy(address(scoreManagerImplementation), "");
        scoreManagerInstance = ScoreManager(address(scoreManagerProxy));
        scoreManagerInstance.initialize();

        regulationsManagerImplementation = new RegulationsManager();
        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation), "");
        regulationsManagerInstance = RegulationsManager(address(regulationsManagerProxy));
        regulationsManagerInstance.initialize();

        EarlyAdopterPool earlyAdopterPool = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxETH),
            address(cbETH)
        );

        claimReceiverPoolImplementation = new ClaimReceiverPool();
        claimReceiverPoolProxy = new UUPSProxy(
            address(claimReceiverPoolImplementation),
            ""
        );
        claimReceiverPoolInstance = ClaimReceiverPool(
            payable(address(claimReceiverPoolProxy))
        );

        //NB: THESE ARE TEST ADDRESSES
        claimReceiverPoolInstance.initialize(
            address(rETH),
            address(wstETH),
            address(sfrxETH),
            address(cbETH),
            address(regulationsManagerInstance),
            0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6,
            0xE592427A0AEce92De3Edee1F18E0157C05861564
        );

        vm.stopBroadcast();

        addressStruct = addresses({
            earlyAdopterPool: address(earlyAdopterPool),
            receiverPool: address(claimReceiverPoolInstance)
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
        string memory versionString = vm.readLine("release/logs/ClaimReceiverTest/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/ClaimReceiverTest/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/ClaimReceiverTest/",
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
                    Strings.toHexString(addressStruct.receiverPool)
                )
            )
        );
    }
}
