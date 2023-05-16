// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/StakingManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StakingManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address StakingManagerProxy;
        address StakingManagerImplementation;
    }

    CriticalAddresses criticalAddresses;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");

        // mainnet
        require(stakingManagerProxyAddress == 0x25e821b7197B146F7713C3b89B6A4D83516B912d, "stakingManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManager stakingManagerV2Implementation = new StakingManager();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManager stakingManagerV2Instance = StakingManager(stakingManagerProxyAddress);

        vm.stopBroadcast();
        
        criticalAddresses = CriticalAddresses({
            StakingManagerProxy: stakingManagerProxyAddress,
            StakingManagerImplementation: address(stakingManagerV2Implementation)
        });

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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/StakingManager/version.txt");
        // Read Global Current version
        string memory globalVersionString = vm.readLine("release/logs/Upgrades/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);
        uint256 globalVersion = _stringToUint(globalVersionString);

        localVersion++;
        globalVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/StakingManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );
        vm.writeFile(
            "release/logs/Upgrades/version.txt",
            string(abi.encodePacked(Strings.toString(globalVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/StakingManager/",
                    Strings.toString(localVersion),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(localVersion),
                    "\nProxy Address: ",
                    Strings.toHexString(criticalAddresses.StakingManagerProxy),
                    "\nNew Implementation Address: ",
                    Strings.toHexString(criticalAddresses.StakingManagerImplementation),
                    "\nOptional Comments: ", 
                    "Comment Here"
                )
            )
        );
    }
}