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
        // Merkle merkle = new Merkle();
        // bytes32[] memory data = new bytes32[](5);
        // data[0] = bytes32(
        //     keccak256(
        //         abi.encodePacked(0x1c5fffDbFDE331A10Ab1e32da8c4Dff210B43145)
        //     )
        // );
        // data[1] = bytes32(
        //     keccak256(
        //         abi.encodePacked(0x2f2806e8b288428f23707A69faA60f52BC565c17)
        //     )
        // );
        // data[2] = bytes32(
        //     keccak256(
        //         abi.encodePacked(0x5dfb8BC4830ccF60d469D546aEC36531c97B96b5)
        //     )
        // );
        // data[3] = bytes32(
        //     keccak256(
        //         abi.encodePacked(0x4507cfB4B077d5DBdDd520c701E30173d5b59Fad)
        //     )
        // );
        // data[4] = bytes32(
        //     keccak256(
        //         abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)
        //     )
        // );

        // bytes32 root = merkle.getRoot(data);
        // bytes32[] memory proofOne = merkle.getProof(data, 0);
        // bytes32[] memory proofTwo = merkle.getProof(data, 1);
        // bytes32[] memory proofThree = merkle.getProof(data, 2);
        // bytes32[] memory proofFour = merkle.getProof(data, 3);
        // bytes32[] memory proofFive = merkle.getProof(data, 4);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        Auction auction = new Auction(address(treasury));
        Deposit deposit = new Deposit(address(auction));
        (address TNFTAddress, address BNFTAddress) = deposit.getNFTAdresses();
        auction.setDepositContractAddress(address(deposit));
        //auction.updateMerkleRoot(root);

        vm.stopBroadcast();

        // Sets the variables to be wriiten to contract addresses.txt
        string memory treasuryAddress = Strings.toHexString(address(treasury));
        string memory auctionAddress = Strings.toHexString(address(auction));
        string memory depositAddress = Strings.toHexString(address(deposit));
        string memory TNFTAddrString = Strings.toHexString(TNFTAddress);
        string memory BNFTAddrString = Strings.toHexString(BNFTAddress);

        // Declare version Var
        uint256 version;

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
        string memory versionPath = "release-logs/version.txt";

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
                "release-logs/",
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
                "Treasury Contract Address: ",
                treasuryAddress,
                "\n",
                "Auction Contract Address: ",
                auctionAddress,
                "\n",
                "Deposit Contract Address: ",
                depositAddress,
                "\n",
                "TNFT Contract Address: ",
                TNFTAddrString,
                "\n",
                "BNFT Contract Address: ",
                BNFTAddrString
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
