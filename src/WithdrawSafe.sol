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

    uint256 public constant SCALE = 100;

    address public owner;
    address public treasuryContract;
    address public auctionContract;

    //stake => recipient address => amount
    mapping(uint256 => mapping(address => uint256)) public claimableBalance;
    mapping(uint256 => mapping(address => uint256)) public totalFundsDistributed;

    //where funds came from => recipient = percentage
    mapping(address => mapping(address => uint256)) public recipientPercentages;

    AuctionContractRevenueSplit auctionContractRevenueSplit;
    ValidatorExitRevenueSplit validatorExitRevenueSplit;

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
        auctionContractRevenueSplit = AuctionContractRevenueSplit({
            treasurySplit: 500,
            nodeOperatorSplit: 500,
            tnftHolderSplit: 8010,
            bnftHolderSplit: 990
        });     

        validatorExitRevenueSplit = ValidatorExitRevenueSplit({
            treasurySplit: 500,
            nodeOperatorSplit: 500,
            tnftHolderSplit: 8010,
            bnftHolderSplit: 990
        });      
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------
}
