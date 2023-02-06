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
    mapping(uint256 => mapping(ValidatorRecipientType => uint256)) public claimableBalance;
    mapping(uint256 => mapping(address => uint256)) public totalFundsDistributed;
    mapping(uint256 => ValidatorFundRecipients) public recipientsPerValidator;

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

    function receiveAuctionFunds(uint256 _validatorId) external payable onlyAuctionContract {
        claimableBalance[_validatorId][ValidatorRecipientType.TREASURY] = msg.value * auctionContractRevenueSplit.treasurySplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.OPERATOR] = msg.value * auctionContractRevenueSplit.nodeOperatorSplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] = msg.value * auctionContractRevenueSplit.tnftHolderSplit / SCALE;
        claimableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] = msg.value * auctionContractRevenueSplit.bnftHolderSplit / SCALE;

        emit AuctionFundsReceived(_validatorId, msg.value);
    }

    function setUpValidatorData(
        uint256 _validatorId, 
        address _tnftHolder, 
        address _bnftHolder, 
        address _operator
    ) external onlyDepositContract {
        recipientsPerValidator[_validatorId] = ValidatorFundRecipients({
            tnftHolder: _tnftHolder,
            bnftHolder: _bnftHolder,
            operator: _operator
        });

        emit ValidatorSetUp(_validatorId, treasuryContract, _operator, _tnftHolder, _bnftHolder);
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
