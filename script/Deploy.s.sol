// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/Registration.sol";
import "../src/WithdrawSafeManager.sol";
import "../src/Deposit.sol";
import "../src/Auction.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MyScript is Script {
    using Strings for string;

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

        auctionInstance.setManagerAddress(address(managerInstance));
        depositInstance.setManagerAddress(address(managerInstance));

        LiquidityPool liquidityPool = new LiquidityPool(msg.sender);
        EETH eETH = new EETH(address(liquidityPool));

        vm.stopBroadcast();

        // Sets the variables to be wriiten to contract addresses.txt
        string memory treasuryAddress = Strings.toHexString(address(treasury));
        string memory registrationAddress = Strings.toHexString(registration);
        string memory auctionAddress = Strings.toHexString(address(auction));
        string memory depositAddress = Strings.toHexString(address(deposit));
        string memory TNFTAddrString = Strings.toHexString(TNFTAddress);
        string memory BNFTAddrString = Strings.toHexString(BNFTAddress);
        string memory safeManagerAddress = Strings.toHexString(safeManager);
        string memory liquidityPoolAddress = Strings.toHexString(liquidityPool);
        string memory eETHAddress = Strings.toHexString(eETH);

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
                "Registration Contract Address: ",
                registrationAddress,
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
                BNFTAddrString,
                "Safe Manager Contract Address: ",
                safeManagerAddress,
                "\n",
                "Liquidity Pool Contract Address: ",
                liquidityPoolAddress,
                "\n",
                "eETH Contract Address: ",
                eETHAddress
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
