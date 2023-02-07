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

    uint256 public tnftId;
    uint256 public bnftId;
    address public operatorAddress;

    //recipient => amount
    mapping(ValidatorRecipientType => uint256) public claimableBalance;
    mapping(ValidatorRecipientType => uint256) public totalFundsDistributed;

    TNFT public tnftInstance;
    BNFT public bnftInstance;

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
    constructor(
        address _treasuryContract, 
        address _auctionContract, 
        address _depositContract, 
        address _tnftContract, 
        address _bnftContract
    ) {
        owner = msg.sender;  
        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;    
        depositContract = _depositContract;

        tnftInstance = TNFT(_tnftContract);
        bnftInstance = BNFT(_bnftContract);

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
        claimableBalance[ValidatorRecipientType.TREASURY] += msg.value * auctionContractRevenueSplit.treasurySplit / SCALE;
        claimableBalance[ValidatorRecipientType.OPERATOR] += msg.value * auctionContractRevenueSplit.nodeOperatorSplit / SCALE;
        claimableBalance[ValidatorRecipientType.TNFTHOLDER] += msg.value * auctionContractRevenueSplit.tnftHolderSplit / SCALE;
        claimableBalance[ValidatorRecipientType.BNFTHOLDER] += msg.value * auctionContractRevenueSplit.bnftHolderSplit / SCALE;

        emit AuctionFundsReceived(_validatorId, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function distributeFunds(uint256 _validatorId) public {
        
        uint256 treasuryAmount = claimableBalance[ValidatorRecipientType.TREASURY];
        uint256 operatorAmount = claimableBalance[ValidatorRecipientType.OPERATOR];
        uint256 tnftHolderAmount = claimableBalance[ValidatorRecipientType.TNFTHOLDER];
        uint256 bnftHolderAmount = claimableBalance[ValidatorRecipientType.BNFTHOLDER];

        address tnftHolder = tnftInstance.ownerOf(tnftInstance.getNftId(_validatorId));
        address bnftHolder = tnftInstance.ownerOf(bnftInstance.getNftId(_validatorId));

        //Send treasury funds
        claimableBalance[ValidatorRecipientType.TREASURY] = 0;
        totalFundsDistributed[ValidatorRecipientType.TREASURY] += treasuryAmount;
        (bool sent, ) = treasuryContract.call{value: treasuryAmount}("");
        require(sent, "Failed to send Ether");

        //Send operator funds
        claimableBalance[ValidatorRecipientType.OPERATOR] = 0;
        totalFundsDistributed[ValidatorRecipientType.OPERATOR] += operatorAmount;
        (sent, ) = payable(operatorAddress).call{value: operatorAmount}("");
        require(sent, "Failed to send Ether");

        //Send bnft funds
        claimableBalance[ValidatorRecipientType.BNFTHOLDER] = 0;
        totalFundsDistributed[ValidatorRecipientType.BNFTHOLDER] += bnftHolderAmount;
        (sent, ) = payable(bnftHolder).call{value: bnftHolderAmount}("");
        require(sent, "Failed to send Ether");

        //Send tnft funds
        claimableBalance[ValidatorRecipientType.TNFTHOLDER] = 0;
        totalFundsDistributed[ValidatorRecipientType.TNFTHOLDER] += tnftHolderAmount;
        (sent, ) = payable(tnftHolder).call{value: tnftHolderAmount}("");
        require(sent, "Failed to send Ether");

        uint256 totalAmount = treasuryAmount + operatorAmount + tnftHolderAmount + bnftHolderAmount;

        emit FundsDistributed(totalAmount);

    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    function setOperatorAddress(address _nodeOperator) public onlyDepositContract {
        operatorAddress = _nodeOperator;
    }

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
