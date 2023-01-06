// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/ITreasury.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract Treasury is ITreasury{

//--------------------------------------------------------------------------------------
//---------------------------------  STATE-VARIABLES  ----------------------------------
//--------------------------------------------------------------------------------------
   
    address public owner;

//--------------------------------------------------------------------------------------
//-------------------------------------  EVENTS  ---------------------------------------
//--------------------------------------------------------------------------------------
 
    event Received(address sender, uint256 value);

//--------------------------------------------------------------------------------------
//----------------------------------  CONSTRUCTOR   ------------------------------------
//--------------------------------------------------------------------------------------
   
    constructor() {
        owner = msg.sender;
    }

//--------------------------------------------------------------------------------------
//----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
//--------------------------------------------------------------------------------------
    
    function withdraw() external {
        require(msg.sender == owner, "Only owner function");

        uint256 balance = address(this).balance;
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
