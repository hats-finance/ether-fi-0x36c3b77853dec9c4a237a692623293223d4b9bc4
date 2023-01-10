// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Treasury.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../lib/murky/src/Merkle.sol";

contract MyScript is Script {
    function run() external {
        Merkle merkle = new Merkle();        
        bytes32[] memory data = new bytes32[](2);
        data[0] = bytes32(keccak256(
                abi.encodePacked()
            ));
        data[1] = bytes32(keccak256(
                abi.encodePacked()
            ));   

        bytes32 root = merkle.getRoot(data);
        bytes32[] memory proofOne = merkle.getProof(data, 0); 
        bytes32[] memory proofTwo = merkle.getProof(data, 1); 

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        Auction auction = new Auction(address(treasury));
        Deposit deposit = new Deposit(address(auction));
        auction.setDepositContractAddress(address(deposit));
        auction.updateMerkleRoot(root);

        vm.stopBroadcast();
    }
}