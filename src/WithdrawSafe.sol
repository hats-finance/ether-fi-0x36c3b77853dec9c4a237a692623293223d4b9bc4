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

    event ValidatorSetUp(
        uint256 validatorId, 
        address treasuryAddress, 
        address indexed operatorAddress, 
        address indexed tnftHolder, 
        address indexed bnftHolder
    );
    event AuctionFundsReceived(uint256 indexed validatorId, uint256 indexed amount);

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

    /// @notice Allows the contract to set up a new validator object for receiving funds
    /// @dev Staker address in paramter will always be both the T and BNFT holder on creation
    /// @param _validatorId id of the validatopr to set up
    /// @param _staker the current address of the b and tnft holder for the validator specified
    /// @param _operator the address of the node operator for the validator specified
    function setUpValidatorData(
        uint256 _validatorId, 
        address _staker, 
        address _operator
    ) external onlyDepositContract {
        recipientsPerValidator[_validatorId] = ValidatorFundRecipients({
            tnftHolder: _staker,
            bnftHolder: _staker,
            operator: _operator
        });

        emit ValidatorSetUp(_validatorId, treasuryContract, _operator, _staker, _staker);
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
