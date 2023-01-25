// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyScript is Script {
    using Strings for string;

    function run() external {
        Merkle merkle = new Merkle();
        bytes32[] memory data = new bytes32[](5);
        data[0] = bytes32(
            keccak256(
                abi.encodePacked(0x1c5fffDbFDE331A10Ab1e32da8c4Dff210B43145)
            )
        );
        data[1] = bytes32(
            keccak256(
                abi.encodePacked(0x2f2806e8b288428f23707A69faA60f52BC565c17)
            )
        );
        data[2] = bytes32(
            keccak256(
                abi.encodePacked(0x5dfb8BC4830ccF60d469D546aEC36531c97B96b5)
            )
        );
        data[3] = bytes32(
            keccak256(
                abi.encodePacked(0x4507cfB4B077d5DBdDd520c701E30173d5b59Fad)
            )
        );
        data[4] = bytes32(
            keccak256(
                abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
            )
        );

        bytes32 root = merkle.getRoot(data);
        bytes32[] memory proofOne = merkle.getProof(data, 0);
        bytes32[] memory proofTwo = merkle.getProof(data, 1);
        bytes32[] memory proofThree = merkle.getProof(data, 2);
        bytes32[] memory proofFour = merkle.getProof(data, 3);
        bytes32[] memory proofFive = merkle.getProof(data, 4);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        console.log("Treasury deployed to", address(treasury));
        Auction auction = new Auction(address(treasury));
        console.log("Auction deployed to", address(auction));
        Deposit deposit = new Deposit(address(auction));
        console.log("Deposit deployed to", address(deposit));
        auction.setDepositContractAddress(address(deposit));
        auction.updateMerkleRoot(root);

        vm.stopBroadcast();

        // Sets the variables to be wriiten to contract addresses.txt
        string memory treasuryName = "Treasury Contract Address: ";
        string memory treasuryAddress = Strings.toHexString(address(treasury));
        string memory auctionName = "Auction Contract Address: ";
        string memory auctionAddress = Strings.toHexString(address(auction));
        string memory depositName = "Deposit Contract Address: ";
        string memory depositAddress = Strings.toHexString(address(deposit));

        // Sets the filename and concatenates data
        string memory path = "contract_addresses.txt";
        string memory writeData = string(
            abi.encodePacked(
                treasuryName,
                " ",
                treasuryAddress,
                "\n",
                auctionName,
                " ",
                auctionAddress,
                "\n",
                depositName,
                " ",
                depositAddress
            )
        );

        // Writes the data to external Contract_Address.txt file
        vm.writeFile(path, writeData);
    }
}
