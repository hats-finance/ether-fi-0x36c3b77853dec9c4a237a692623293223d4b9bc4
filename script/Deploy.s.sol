// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Treasury.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        Auction auction = new Auction(address(treasury));
        Deposit deposit = new Deposit(address(auction));
        auction.setDepositContractAddress(address(deposit));

        vm.stopBroadcast();
    }
}