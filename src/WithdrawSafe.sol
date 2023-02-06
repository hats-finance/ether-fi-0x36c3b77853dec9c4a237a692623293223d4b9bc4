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
    address public depositContract;

    //validatorId => recipient address => amount
    mapping(uint256 => mapping(address => uint256)) public claimableBalance;
    mapping(uint256 => mapping(address => uint256)) public totalFundsDistributed;
    mapping(uint256 => ValidatorFundRecipients) public recipientsPerValidator;

    AuctionContractRevenueSplit public auctionContractRevenueSplit;
    ValidatorExitRevenueSplit public validatorExitRevenueSplit;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(address _owner, address _treasuryContract, address _auctionContract, address _depositContract) {
        owner = _owner;  
        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;    
        depositContract = _depositContract;
        
        auctionContractRevenueSplit = AuctionContractRevenueSplit({
            treasurySplit: 5,
            nodeOperatorSplit: 5,
            tnftHolderSplit: 81,
            bnftHolderSplit: 9
        });     

        validatorExitRevenueSplit = ValidatorExitRevenueSplit({
            treasurySplit: 5,
            nodeOperatorSplit: 5,
            tnftHolderSplit: 81,
            bnftHolderSplit: 9
        });      
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function receiveAuctionFunds(uint256 _validatorId) external payable onlyAuctionContract {
        
        claimableBalance[_validatorId][treasuryContract] = msg.value * auctionContractRevenueSplit.treasurySplit / SCALE;
        claimableBalance[_validatorId][recipientsPerValidator[_validatorId].tnftHolder] = msg.value * auctionContractRevenueSplit.tnftHolderSplit / SCALE;
        claimableBalance[_validatorId][recipientsPerValidator[_validatorId].bnftHolder] = msg.value * auctionContractRevenueSplit.bnftHolderSplit / SCALE;
        claimableBalance[_validatorId][recipientsPerValidator[_validatorId].operator] = msg.value * auctionContractRevenueSplit.nodeOperatorSplit / SCALE;

    }

    function setUpValidatorData(uint256 _validatorId, address _tnftHolder, address _bnftHolder, address _operator) external onlyDepositContract {
        recipientsPerValidator[_validatorId] = ValidatorFundRecipients({
            tnftHolder: _tnftHolder,
            bnftHolder: _bnftHolder,
            operator: _operator
        });
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyAuctionContract() {
        require(msg.sender == auctionContract, "Incorrect caller");
        _;
    }

    modifier onlyDepositContract() {
        require(msg.sender == depositContract, "Incorrect caller");
        _;
    }
}
