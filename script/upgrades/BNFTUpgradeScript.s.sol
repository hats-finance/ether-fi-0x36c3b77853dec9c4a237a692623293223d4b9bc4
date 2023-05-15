// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/BNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BNFTUpgrade is Script {
    using Strings for string;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address BNFTProxyAddress = vm.envAddress("BNFT_PROXY_ADDRESS");

        // mainnet
        require(BNFTProxyAddress == 0x6599861e55abd28b91dd9d86A826eC0cC8D72c2c, "BNFTProxyAddress incorrect see .env");

        vm.startBroadcast(deployerPrivateKey);

        BNFT BNFTInstance = BNFT(BNFTProxyAddress);
        BNFT BNFTV2Implementation = new BNFT();

        BNFTInstance.upgradeTo(address(BNFTV2Implementation));
        BNFT BNFTV2Instance = BNFT(BNFTProxyAddress);

        vm.stopBroadcast();
    }
}