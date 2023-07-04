// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/StakingManager.sol";
import "../../../src/helpers/GoerliAddressProvider.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract StakingManagerUpgrade is Script {
    using Strings for string;

    struct CriticalAddresses {
        address StakingManagerProxy;
        address StakingManagerImplementation;
    }

    CriticalAddresses criticalAddresses;
    GoerliAddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = GoerliAddressProvider(addressProviderAddress);

        address stakingManagerProxyAddress = addressProvider.getProxyAddress("StakingManager");

        require(stakingManagerProxyAddress == 0x482f265d8D850fa6440e42b0B299C044caEB879a, "stakingManagerProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        StakingManager stakingManagerInstance = StakingManager(stakingManagerProxyAddress);
        StakingManager stakingManagerV2Implementation = new StakingManager();

        stakingManagerInstance.upgradeTo(address(stakingManagerV2Implementation));
        StakingManager stakingManagerV2Instance = StakingManager(stakingManagerProxyAddress);
        
        addressProvider.updateContractImplementation(1, address(stakingManagerV2Implementation));

        vm.stopBroadcast();
        
        criticalAddresses = CriticalAddresses({
            StakingManagerProxy: stakingManagerProxyAddress,
            StakingManagerImplementation: address(stakingManagerV2Implementation)
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
        string memory localVersionString = vm.readLine("release/logs/Upgrades/goerli/StakingManager/version.txt");

        // Cast string to uint256
        uint256 localVersion = _stringToUint(localVersionString);

        localVersion++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/Upgrades/goerli/StakingManager/version.txt",
            string(abi.encodePacked(Strings.toString(localVersion)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/Upgrades/goerli/StakingManager/",
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