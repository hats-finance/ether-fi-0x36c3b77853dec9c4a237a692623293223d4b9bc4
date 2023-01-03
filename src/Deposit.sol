// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Deposit {

    TNFT public TNFTInstance;
    BNFT public BNFTInstance;

    uint256 public stakeAmount;

    mapping(address => uint256) public depositorBalances;

    constructor() {
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
        stakeAmount = 0.1 ether;
    }

    function deposit() public payable {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
        BNFTInstance.mint(msg.sender);
        depositorBalances[msg.sender] += msg.value;
    }
}