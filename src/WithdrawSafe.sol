// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IWithdrawSafe.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract WithdrawSafe is IWithdrawSafe {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public owner;
    address public treasuryContract;
    address public auctionContract;

    //stake => recipient address => amount
    mapping(uint256 => mapping(address => uint256)) public claimableBalance;
    mapping(uint256 => mapping(address => uint256)) public totalFundsDistributed;

    //where funds came from => recipient = percentage
    mapping(address => mapping(address => uint256)) public recipientPercentages;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(address _owner, address _treasuryContract, address _auctionContract) {
        owner = _owner;  
        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;          
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function setUpNewStake(
        address _nodeOperator, 
        address _tnftHolder, 
        address _bnftHolder
    ) external {

        recipientPercentages[auctionContract][_nodeOperator] = 5;
        recipientPercentages[auctionContract][_tnftHolder] = 80;
        recipientPercentages[auctionContract][_bnftHolder] = 10;
        recipientPercentages[auctionContract][treasuryContract] = 5;
        recipientPercentages[address(this)][_nodeOperator] = 5;
        recipientPercentages[address(this)][_tnftHolder] = 80;
        recipientPercentages[address(this)][_bnftHolder] = 10;
        recipientPercentages[address(this)][treasuryContract] = 5;

    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------
}
