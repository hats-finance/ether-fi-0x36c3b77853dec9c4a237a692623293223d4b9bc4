// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Deposit {

    TNFT public TNFTInstance;
    BNFT public BNFTInstance;

    constructor() {
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
    }

    function deposit() public payable {
        require(msg.value >= 0.1 ether, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
        BNFTInstance.mint(msg.sender);
    }
}