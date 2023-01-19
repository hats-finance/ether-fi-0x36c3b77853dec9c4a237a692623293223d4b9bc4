// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Deposit {

//--------------------------------------------------------------------------------------
//---------------------------------  STATE-VARIABLES  ----------------------------------
//--------------------------------------------------------------------------------------
    
    TNFT public TNFTInstance;
    BNFT public BNFTInstance;
    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuction public auctionInterfaceInstance;
    uint256 public stakeAmount;
    uint256 public numberOfStakes;

    mapping(address => uint256) public depositorBalances;
    mapping(address => mapping(uint256 => address)) public stakeToOperator;

//--------------------------------------------------------------------------------------
//-------------------------------------  EVENTS  ---------------------------------------
//--------------------------------------------------------------------------------------
 
    event StakeDeposit(address indexed sender, uint256 value);

//--------------------------------------------------------------------------------------
//----------------------------------  CONSTRUCTOR   ------------------------------------
//--------------------------------------------------------------------------------------
   
    /// @notice Constructor to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev Auction contract must be deployed first
    /// @param _auctionAddress the address of the auction contract for interaction
    constructor(address _auctionAddress) {
        stakeAmount = 0.032 ether;
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
        TNFTInterfaceInstance = ITNFT(address(TNFTInstance));
        BNFTInterfaceInstance = IBNFT(address(BNFTInstance));
        auctionInterfaceInstance = IAuction(_auctionAddress);
    }

//--------------------------------------------------------------------------------------
//----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
//--------------------------------------------------------------------------------------
    
    /// @notice Allows a user to stake their ETH
    /// @dev This is phase 1 of the staking process, validation key submition is phase 2
    /// @dev Function disables bidding until it is manually enabled again or validation key is submitted
    function deposit() public payable {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >= 1,
            "No bids available at the moment"
        );

        //Mints two NFTs to the staker
        TNFTInterfaceInstance.mint(msg.sender);
        BNFTInterfaceInstance.mint(msg.sender);
        depositorBalances[msg.sender] += msg.value;

        //Disables the bidding in the auction contract
        address winningOperatorAddress = auctionInterfaceInstance.disableBidding();

        //Adds the winning operator to the mapping to store which address won which stake
        stakeToOperator[msg.sender][numberOfStakes] = winningOperatorAddress;

        emit StakeDeposit(msg.sender, msg.value);
    }

    /// @notice Refunds the depositor their 32 ether
    /// @dev Gets called internally from cancelDeposit or when the time runs out for calling registerValidator
    /// @param _depositOwner address of the user being refunded
    /// @param _amount the amount to refund the depositor
    function refundDeposit(address _depositOwner, uint256 _amount) public {
        require(_amount % stakeAmount == 0, "Invalid refund amount");
        require(depositorBalances[_depositOwner] >= _amount, "Insufficient balance");

        //Reduce the depositers balance
        depositorBalances[_depositOwner] -= _amount;

        //Refund the user with their requested amount
        (bool sent, ) = _depositOwner.call{value: _amount}("");
        require(sent, "Failed to send Ether");

    }
}
