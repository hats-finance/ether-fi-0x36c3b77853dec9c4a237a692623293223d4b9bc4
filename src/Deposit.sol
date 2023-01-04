// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Deposit {
    TNFT public TNFTInstance;
    BNFT public BNFTInstance;
    IAuction public auctionInterfaceInstance;

    uint256 public stakeAmount = 0.1 ether;
    address public owner;
    address public auctionAddress;

    mapping(address => uint256) public depositorBalances;

    event StakeDeposit(address sender, uint256 value);

    constructor(address _auctionAddress) {
        owner = msg.sender;
        TNFTInstance = new TNFT(msg.sender);
        BNFTInstance = new BNFT(msg.sender);
        auctionInterfaceInstance = IAuction(_auctionAddress);
        auctionInterfaceInstance.setDepositContractAddress(address(this));
        auctionInterfaceInstance.startAuction();
    }

    function deposit() public payable {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        TNFTInstance.mint(msg.sender);
        BNFTInstance.mint(msg.sender);
        depositorBalances[msg.sender] += msg.value;

        auctionInterfaceInstance.closeAuction();

        emit StakeDeposit(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
