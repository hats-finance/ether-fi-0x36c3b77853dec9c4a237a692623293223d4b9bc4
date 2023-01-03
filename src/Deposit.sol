// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./interfaces/ITNFT.sol";

contract Deposit {

    ITNFT TNFTInstance;

    constructor(address _TNFTAddress) public {
        TNFTInstance = ITNFT(_TNFTAddress);
    }

    function deposit() public payable {
        require(msg.value >= 32 ether, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
    }

}