// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IWithdrawSafe.sol";
import "./interfaces/IWithdrawSafeManager.sol";
import "./interfaces/IDeposit.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "lib/forge-std/src/console.sol";

contract WithdrawSafeManager is IWithdrawSafeManager {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public constant SCALE = 100;

    address public owner;
    address public treasuryContract;
    address public auctionContract;
    address public depositContract;

    mapping(uint256 => mapping(ValidatorRecipientType => uint256))
        public withdrawableBalance;
    mapping(uint256 => mapping(ValidatorRecipientType => uint256))
        public withdrawn;
    mapping(uint256 => address) public withdrawSafeAddressesPerValidator;
    mapping(uint256 => uint256) public fundsReceivedFromAuctions;
    mapping(uint256 => address) public operatorAddresses;

    TNFT public tnftInstance;
    BNFT public bnftInstance;
    IDeposit public depositInstance;

    //Holds the data for the revenue splits depending on where the funds are received from
    AuctionContractRevenueSplit public auctionContractRevenueSplit;
    ValidatorExitRevenueSplit public validatorExitRevenueSplit;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------
    event Received(address indexed sender, uint256 value);
    event BidRefunded(uint256 indexed _bidId, uint256 indexed _amount);

    event AuctionFundsReceived(uint256 indexed amount);
    event FundsDistributed(uint256 indexed totalFundsTransferred);
    event OperatorAddressSet(address indexed operater);
    event FundsWithdrawn(uint256 indexed amount);

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

        depositInstance = IDeposit(_depositContract);

        tnftInstance = TNFT(_tnftContract);
        bnftInstance = BNFT(_bnftContract);

        auctionContractRevenueSplit = AuctionContractRevenueSplit({
            treasurySplit: 10,
            nodeOperatorSplit: 10,
            tnftHolderSplit: 60,
            bnftHolderSplit: 20
        });

        validatorExitRevenueSplit = ValidatorExitRevenueSplit({
            treasurySplit: 5,
            nodeOperatorSplit: 5,
            tnftHolderSplit: 81,
            bnftHolderSplit: 9
        });

        depositInstance.setManagerAddress(address(this));
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Updates the total amount of funds receivable for recipients of the specified validator
    /// @dev Takes in a certain value of funds from only the set auction contract
    function receiveAuctionFunds(uint256 _validatorId, uint256 _amount)
        external
    {
        require(
            msg.sender == auctionContract,
            "Only auction contract function"
        );        withdrawableBalance[_validatorId][ValidatorRecipientType.TREASURY] +=
            (_amount * auctionContractRevenueSplit.treasurySplit) /
            SCALE;

        withdrawableBalance[_validatorId][ValidatorRecipientType.OPERATOR] +=
            (_amount * auctionContractRevenueSplit.nodeOperatorSplit) /
            SCALE;

        withdrawableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] +=
            (_amount * auctionContractRevenueSplit.tnftHolderSplit) /
            SCALE;

        withdrawableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] +=
            (_amount * auctionContractRevenueSplit.bnftHolderSplit) /
            SCALE;

        fundsReceivedFromAuctions[_validatorId] += _amount;
        emit AuctionFundsReceived(_amount);
    }

    /// @notice updates claimable balances based on funds received from validator and distributes the funds
    /// @dev Need to think about distribution if there has been slashing
    function withdrawFunds(uint256 _validatorId) external {
        require(
            msg.sender ==
                depositInstance.getStakerRelatedToValidator(_validatorId),
            "Incorrect caller"
        );
        //Will check oracle to make sure validator has exited

        uint256 contractBalance = address(
            withdrawSafeAddressesPerValidator[_validatorId]
        ).balance;
        
        uint256 validatorRewards = contractBalance -
            depositInstance.getStakeAmount() -
            fundsReceivedFromAuctions[_validatorId];

        withdrawableBalance[_validatorId][
            ValidatorRecipientType.BNFTHOLDER
        ] += bnftInstance.nftValue();
        withdrawableBalance[_validatorId][
            ValidatorRecipientType.TNFTHOLDER
        ] += tnftInstance.nftValue();

        withdrawableBalance[_validatorId][ValidatorRecipientType.TREASURY] +=
            (validatorRewards * validatorExitRevenueSplit.treasurySplit) /
            SCALE;
        withdrawableBalance[_validatorId][ValidatorRecipientType.OPERATOR] +=
            (validatorRewards * validatorExitRevenueSplit.nodeOperatorSplit) /
            SCALE;
        withdrawableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] +=
            (validatorRewards * validatorExitRevenueSplit.tnftHolderSplit) /
            SCALE;
        withdrawableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] +=
            (validatorRewards * validatorExitRevenueSplit.bnftHolderSplit) /
            SCALE;

        uint256 treasuryAmount = withdrawableBalance[_validatorId][
            ValidatorRecipientType.TREASURY
        ];
        uint256 operatorAmount = withdrawableBalance[_validatorId][
            ValidatorRecipientType.OPERATOR
        ];
        uint256 tnftHolderAmount = withdrawableBalance[_validatorId][
            ValidatorRecipientType.TNFTHOLDER
        ];
        uint256 bnftHolderAmount = withdrawableBalance[_validatorId][
            ValidatorRecipientType.BNFTHOLDER
        ];

        address tnftHolder = tnftInstance.ownerOf(
            tnftInstance.getNftId(_validatorId)
        );
        address bnftHolder = tnftInstance.ownerOf(
            bnftInstance.getNftId(_validatorId)
        );

        withdrawableBalance[_validatorId][ValidatorRecipientType.TREASURY] = 0;
        withdrawn[_validatorId][ValidatorRecipientType.TREASURY] += treasuryAmount;
        withdrawableBalance[_validatorId][ValidatorRecipientType.OPERATOR] = 0;
        withdrawn[_validatorId][ValidatorRecipientType.OPERATOR] += operatorAmount;
        withdrawableBalance[_validatorId][ValidatorRecipientType.BNFTHOLDER] = 0;
        withdrawn[_validatorId][ValidatorRecipientType.BNFTHOLDER] += bnftHolderAmount;
        withdrawableBalance[_validatorId][ValidatorRecipientType.TNFTHOLDER] = 0;
        withdrawn[_validatorId][ValidatorRecipientType.TNFTHOLDER] += tnftHolderAmount;

        
        fundsReceivedFromAuctions[_validatorId] = 0;
        
        IWithdrawSafe safeInstance = IWithdrawSafe(
            withdrawSafeAddressesPerValidator[_validatorId]
        );
        
        safeInstance.withdrawFunds(
            treasuryContract,
            treasuryAmount,
            operatorAddresses[_validatorId],
            operatorAmount,
            tnftHolder,
            tnftHolderAmount,
            bnftHolder,
            bnftHolderAmount
        );

        emit FundsWithdrawn(contractBalance);
    }
   
    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets the node operator address for the withdraw safe
    /// @param _nodeOperator address of the operator to be set
    function setOperatorAddress(uint256 _validatorId, address _nodeOperator)
        public
        onlyDepositContract
    {
        require(_nodeOperator != address(0), "Cannot be address 0");
        operatorAddresses[_validatorId] = _nodeOperator;

        emit OperatorAddressSet(_nodeOperator);
    }

    /// @notice Sets the validator ID for the withdraw safe
    /// @param _validatorId id of the validator associated to this withdraw safe
    function setWithdrawSafeAddress(uint256 _validatorId, address _safeAddress)
        public
        onlyDepositContract
    {
        withdrawSafeAddressesPerValidator[_validatorId] = _safeAddress;

    }

    function getWithdrawSafeAddress(uint256 _validatorId) public returns(address) {
        return withdrawSafeAddressesPerValidator[_validatorId];
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContract,
            "Only deposit contract function"
        );
        _;
    }
}
