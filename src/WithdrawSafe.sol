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
    address public tnftHolder;
    address public bnftHolder;
    address public operatorAddress;

    //recipient => amount
    mapping(address => uint256) public claimableBalance;
    mapping(address => uint256) public totalFundsDistributed;

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
        claimableBalance[treasuryContract] += msg.value * auctionContractRevenueSplit.treasurySplit / SCALE;
        claimableBalance[operatorAddress] += msg.value * auctionContractRevenueSplit.nodeOperatorSplit / SCALE;
        claimableBalance[tnftHolder] += msg.value * auctionContractRevenueSplit.tnftHolderSplit / SCALE;
        claimableBalance[bnftHolder] += msg.value * auctionContractRevenueSplit.bnftHolderSplit / SCALE;

        emit AuctionFundsReceived(_validatorId, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function distributeFunds(uint256 _validatorId) public {
        
        uint256 treasuryAmount = claimableBalance[treasuryContract];
        uint256 operatorAmount = claimableBalance[operatorAddress];
        uint256 tnftHolderAmount = claimableBalance[tnftHolder];
        uint256 bnftHolderAmount = claimableBalance[bnftHolder];

        //Send treasury funds
        claimableBalance[treasuryContract] = 0;
        (bool sent, ) = treasuryContract.call{value: treasuryAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[treasuryContract] += treasuryAmount;

        //Send operator funds
        claimableBalance[operatorAddress] = 0;
        (sent, ) = payable(operatorAddress).call{value: operatorAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[operatorAddress] += operatorAmount;

        //Send bnft funds
        claimableBalance[bnftHolder] = 0;
        (sent, ) = payable(bnftHolder).call{value: bnftHolderAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[bnftHolder] += bnftHolderAmount;

        //Send tnft funds
        claimableBalance[tnftHolder] = 0;
        (sent, ) = payable(tnftHolder).call{value: tnftHolderAmount}("");
        require(sent, "Failed to send Ether");
        totalFundsDistributed[tnftHolder] += tnftHolderAmount;

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
