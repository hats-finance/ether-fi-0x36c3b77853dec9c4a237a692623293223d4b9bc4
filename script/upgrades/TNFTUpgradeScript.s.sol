// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/TNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TNFTUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address TNFTProxyAddress = vm.envAddress("TNFT_PROXY_ADDRESS");

        // mainnet
        require(TNFTProxyAddress == 0x7B5ae07E2AF1C861BcC4736D23f5f66A61E0cA5e, "TNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        TNFT TNFTInstance = TNFT(TNFTProxyAddress);
        TNFT TNFTV2Implementation = new TNFT();

        TNFTInstance.upgradeTo(address(TNFTV2Implementation));
        TNFT TNFTV2Instance = TNFT(TNFTProxyAddress);

        vm.stopBroadcast();
    }
}