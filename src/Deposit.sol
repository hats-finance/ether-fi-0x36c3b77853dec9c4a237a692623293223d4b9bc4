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
    address public owner;

    mapping(address => uint256) public depositorBalances;

    event Deposit(address sender, uint256 value);
    event UpdateStakeAmount(uint256 oldStakeAmount, uint256 newStakeAmount);

    constructor() {
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
        stakeAmount = 0.1 ether;
        owner = msg.sender;
    }

    function deposit() public payable {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
        BNFTInstance.mint(msg.sender);
        depositorBalances[msg.sender] += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    function setStakeAmount(uint256 _newStakeAmount) public onlyOwner {
        uint256 public oldStakeAmount = stakeAmount;
        stakeAmount = _newStakeAmount;

        emit UpdateStakeAmount(oldStakeAmount, _newStakeAmount);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}