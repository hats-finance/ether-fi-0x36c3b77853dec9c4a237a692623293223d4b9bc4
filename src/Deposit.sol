// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";

contract Deposit {

    ITNFT TNFTInstance;

    constructor(address _TNFTAddress) {
        TNFTInstance = ITNFT(_TNFTAddress);
    }

    function deposit() public payable {
        require(msg.value >= 32 ether, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
    }
}