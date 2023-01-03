// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";

contract Deposit {

    ITNFT TNFTInstance;
    IBNFT BNFTInstance;

    constructor(address _TNFTAddress, address _BNFTAddress) {
        TNFTInstance = ITNFT(_TNFTAddress);
        BNFTInstance = IBNFT(_BNFTAddress);
    }

    function deposit() public payable {
        require(msg.value >= 32 ether, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
        BNFTInstance.mint(msg.sender);
    }
}