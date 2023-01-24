// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/ITreasury.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Treasury is ITreasury {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public owner;
    address private auctionContractAddress;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Received(address indexed sender, uint256 value);
    event BidRefunded(uint256 indexed _bidId, uint256 indexed _amount);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor() {
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Function allows only the owner to withdraw all the funds in the contract
    function withdraw() external {
        require(msg.sender == owner, "Only owner function");

        uint256 balance = address(this).balance;
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }

    function refundBid(uint256 _amount, uint256 _bidId) external {
        (bool sent, ) = auctionContractAddress.call{value: _amount}("");
        require(sent, "refund failed");

        emit BidRefunded(_bidId, _amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /*------ Setters ------*/

    function setAuctionContractAddress(address _auctionContractAddress)
        public
        onlyOwner
    {
        auctionContractAddress = _auctionContractAddress;
    }

    /*------ Modifiers ------*/
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }

    modifier onlyAuctionContract() {
        require(
            msg.sender == auctionContractAddress,
            "Only auction contract function"
        );
        _;
    }
}
