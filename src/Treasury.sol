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
    address public auctionContractAddress;

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
    function withdraw() external onlyOwner {
=
        uint256 balance = address(this).balance;
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Refunds a winning bid of a deposit which has been cancelled
    /// @dev Must only be called by the auction contract
    /// @param _amount the amount of the bid to refund
    /// @param _bidId the id of the bid to refund
    function refundBid(uint256 _amount, uint256 _bidId)
        external
        onlyAuctionContract
    {
        (bool sent, ) = auctionContractAddress.call{value: _amount}("");
        require(sent, "refund failed");

        emit BidRefunded(_bidId, _amount);
    }

    //Allows ether to be sent to this contract
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets the auctionContract address in the current contract
    /// @dev Called when auction contract is deployed
    /// @param _auctionContractAddress address of the auctionContract for authorizations
    function setAuctionContractAddress(address _auctionContractAddress)
        public
        onlyOwner
    {
        auctionContractAddress = _auctionContractAddress;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "AC101");
        _;
    }

    modifier onlyAuctionContract() {
        require(
            msg.sender == auctionContractAddress,
            "AC103"
        );
        _;
    }
}
