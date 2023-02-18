// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/Registration.sol";
import "../src/WithdrawSafeManager.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployScript is Script {
    using Strings for string;

    struct addresses {
        address treasury;
        address registration;
        address auction;
        address deposit;
        address TNFT;
        address BNFT;
        address safeManager;
    }

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        Treasury treasury = new Treasury();
        Registration registration = new Registration();
        Auction auction = new Auction(address(registration));

        treasury.setAuctionContractAddress(address(auction));

        vm.recordLogs();

        Deposit deposit = new Deposit(address(auction));
        auction.setDepositContractAddress(address(deposit));

        Vm.Log[] memory entries = vm.getRecordedLogs();

        (address TNFTAddress, address BNFTAddress) = abi.decode(
            entries[0].data,
            (address, address)
        );

        WithdrawSafeManager safeManager = new WithdrawSafeManager(
            address(treasury),
            address(auction),
            address(deposit),
            TNFTAddress,
            BNFTAddress
        );

        auction.setManagerAddress(address(safeManager));
        deposit.setManagerAddress(address(safeManager));

        vm.stopBroadcast();

        addressStruct = addresses({
            treasury: address(treasury),
            registration: address(registration),
            auction: address(auction),
            deposit: address(deposit),
            TNFT: TNFTAddress,
            BNFT: BNFTAddress,
            safeManager: address(safeManager)
        });

        writeVersionFile();

        // Set path to version file where current verion is recorded
        /// @dev Initial version.txt and X.release files should be created manually
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
                    "\n",
                    Strings.toHexString(addressStruct.treasury),
                    "\n",
                    Strings.toHexString(addressStruct.registration),
                    "\n",
                    Strings.toHexString(addressStruct.auction),
                    "\n",
                    Strings.toHexString(addressStruct.deposit),
                    "\n",
                    Strings.toHexString(addressStruct.TNFT),
                    "\n",
                    Strings.toHexString(addressStruct.BNFT),
                    "\n",
                    Strings.toHexString(addressStruct.safeManager)
                )
            )
        );
    }
}
