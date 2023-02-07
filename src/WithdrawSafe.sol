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

    //validatorId => recipient type => amount
    mapping(uint256 => mapping(ValidatorRecipientType => uint256)) public claimableBalance;
    mapping(uint256 => mapping(ValidatorRecipientType => uint256)) public totalFundsDistributed;

    //Mapping to store the fund recipients for each validator
    mapping(uint256 => ValidatorFundRecipients) public recipientsPerValidator;

    //Holds the data for the revenue splits depending on where the funds are received from
    AuctionContractRevenueSplit public auctionContractRevenueSplit;
    ValidatorExitRevenueSplit public validatorExitRevenueSplit;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event AuctionFundsReceived(uint256 indexed validatorId, uint256 indexed amount);
    event FundsDistributed(uint256 indexed totalFundsTransferred);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    /// @dev Sets the revenue splits on deployment
    /// @dev Auction, treasury and deposit contracts must be deployed first
    /// @param _treasuryContract the address of the treasury contract for interaction
    /// @param _auctionContract the address of the auction contract for interaction
    /// @param _depositContract the address of the deposit contract for interaction
    constructor(address _treasuryContract, address _auctionContract, address _depositContract) {
        owner = msg.sender;  
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

    /// @notice Updates the total amount of funds receivable for recipients of the specified validator
    /// @dev Takes in a certain value of funds from only the set auction contract
    /// @param _validatorId id of the validatopr to store the funds for
    function receiveAuctionFunds(uint256 _validatorId) external payable onlyAuctionContract {
        claimableBalance[_validatorId][ValidatorRecipientType.TREASURY] = msg.value * auctionContractRevenueSplit.treasurySplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.OPERATOR] = msg.value * auctionContractRevenueSplit.nodeOperatorSplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] = msg.value * auctionContractRevenueSplit.tnftHolderSplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] = msg.value * auctionContractRevenueSplit.bnftHolderSplit / SCALE;

        emit AuctionFundsReceived(_validatorId, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function distributeFunds(uint256 _validatorId) public {
        
        uint256 treasuryAmount = claimableBalance[_validatorId][ValidatorRecipientType.TREASURY];
        uint256 operatorAmount = claimableBalance[_validatorId][ValidatorRecipientType.OPERATOR];
        uint256 tnftHolderAmount = claimableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER];
        uint256 bnftHolderAmount = claimableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER];

        //Send treasury funds
        claimableBalance[_validatorId][ValidatorRecipientType.TREASURY] = 0;
        (bool sent, ) = treasuryContract.call{value: treasuryAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[_validatorId][ValidatorRecipientType.TREASURY] += treasuryAmount;

        //Send operator funds
        claimableBalance[_validatorId][ValidatorRecipientType.OPERATOR] = 0;
        (sent, ) = payable(recipientsPerValidator[_validatorId].operator).call{value: operatorAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[_validatorId][ValidatorRecipientType.OPERATOR] += operatorAmount;

        //Send bnft funds
        claimableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] = 0;
        (sent, ) = payable(recipientsPerValidator[_validatorId].bnftHolder).call{value: bnftHolderAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[_validatorId][ValidatorRecipientType.BNFTHOLDER] += bnftHolderAmount;

        //Send tnft funds
        claimableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] = 0;
        (sent, ) = payable(recipientsPerValidator[_validatorId].tnftHolder).call{value: tnftHolderAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[_validatorId][ValidatorRecipientType.TNFTHOLDER] += tnftHolderAmount;

        uint256 totalAmount = treasuryAmount + operatorAmount + tnftHolderAmount + bnftHolderAmount;

        emit FundsDistributed(totalAmount);

    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyAuctionContract() {
        require(msg.sender == auctionContract, "Only auction contract function");
        _;
    }

    modifier onlyDepositContract() {
        require(msg.sender == depositContract, "Only deposit contract function");
        _;
    }
}
