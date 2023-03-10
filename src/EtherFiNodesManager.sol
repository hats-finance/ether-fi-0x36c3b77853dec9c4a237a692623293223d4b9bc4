// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IStakingManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./EtherFiNode.sol";
import "lib/forge-std/src/console.sol";

contract EtherFiNodesManager is IEtherFiNodesManager {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public immutable implementationContract;

    uint256 public constant SCALE = 100;

    uint256 public numberOfValidators;

    address public owner;
    address public treasuryContract;
    address public auctionContract;
    address public depositContract;

    mapping(uint256 => mapping(ValidatorRecipientType => uint256))
        public withdrawableBalance;
    mapping(uint256 => mapping(ValidatorRecipientType => uint256))
        public withdrawn;
    mapping(uint256 => address) public etherfiNodePerValidator;
    mapping(uint256 => uint256) public fundsReceivedFromAuction;

    TNFT public tnftInstance;
    BNFT public bnftInstance;
    IStakingManager public stakingManagerInstance;
    IAuctionManager public auctionInterfaceInstance;

    //Holds the data for the revenue splits depending on where the funds are received from
    AuctionManagerContractRevenueSplit public auctionContractRevenueSplit;
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
    /// @dev AuctionManager, treasury and deposit contracts must be deployed first
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
        implementationContract = address(new EtherFiNode());

        owner = msg.sender;
        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;
        depositContract = _depositContract;

        stakingManagerInstance = IStakingManager(_depositContract);
        auctionInterfaceInstance = IAuctionManager(_auctionContract);

        tnftInstance = TNFT(_tnftContract);
        bnftInstance = BNFT(_bnftContract);

        auctionContractRevenueSplit = AuctionManagerContractRevenueSplit({
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

        stakingManagerInstance.setEtherFiNodesManagerAddress(address(this));
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function createEtherfiNode(uint256 _validatorId) external returns (address) {
        address clone = Clones.clone(implementationContract);
        EtherFiNode(payable(clone)).initialize();
        installEtherFiNode(_validatorId, clone);
        return clone;
    }

    /// @notice updates claimable balances based on funds received from validator and distributes the funds
    /// @dev Need to think about distribution if there has been slashing
    function withdrawFunds(uint256 _validatorId) external {
        require(
            msg.sender ==
                stakingManagerInstance.getStakerRelatedToValidator(_validatorId),
            "Incorrect caller"
        );
        //Will check oracle to make sure validator has exited

        uint256 contractBalance = address(
            etherfiNodePerValidator[_validatorId]
        ).balance;

        uint256 validatorRewards = contractBalance -
            stakingManagerInstance.getStakeAmount() -
            fundsReceivedFromAuction[_validatorId];

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

        address tnftHolder = tnftInstance.ownerOf(_validatorId);
        address bnftHolder = tnftInstance.ownerOf(_validatorId);

        withdrawableBalance[_validatorId][ValidatorRecipientType.TREASURY] = 0;
        withdrawn[_validatorId][
            ValidatorRecipientType.TREASURY
        ] += treasuryAmount;
        withdrawableBalance[_validatorId][ValidatorRecipientType.OPERATOR] = 0;
        withdrawn[_validatorId][
            ValidatorRecipientType.OPERATOR
        ] += operatorAmount;
        withdrawableBalance[_validatorId][
            ValidatorRecipientType.BNFTHOLDER
        ] = 0;
        withdrawn[_validatorId][
            ValidatorRecipientType.BNFTHOLDER
        ] += bnftHolderAmount;
        withdrawableBalance[_validatorId][
            ValidatorRecipientType.TNFTHOLDER
        ] = 0;
        withdrawn[_validatorId][
            ValidatorRecipientType.TNFTHOLDER
        ] += tnftHolderAmount;

        fundsReceivedFromAuction[_validatorId] = 0;

        IEtherFiNode safeInstance = IEtherFiNode(
            etherfiNodePerValidator[_validatorId]
        );

        safeInstance.withdrawFunds(
            treasuryContract,
            treasuryAmount,
            auctionInterfaceInstance.getBidOwner(_validatorId),
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

    /// @notice Sets the validator ID for the EtherFiNode contract
    /// @param _validatorId id of the validator associated to the node
    /// @param _etherfiNode address of the EtherFiNode contract
    function installEtherFiNode(uint256 _validatorId, address _etherfiNode)
        public
        onlyStakingManagerContract
    {
        require(etherfiNodePerValidator[_validatorId] == address(0), "already installed");
        etherfiNodePerValidator[_validatorId] = _etherfiNode;
    }

    /// @notice UnSet the EtherFiNode contract for the validator ID 
    /// @param _validatorId id of the validator associated
    function uninstallEtherFiNode(uint256 _validatorId)
        public
        onlyStakingManagerContract
    {
        require(etherfiNodePerValidator[_validatorId] != address(0), "not installed");
        etherfiNodePerValidator[_validatorId] = address(0);
    }

    /// @notice Sets the phase of the validator
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _phase phase of the validator
    function setEtherFiNodePhase(uint256 _validatorId, IEtherFiNode.VALIDATOR_PHASE _phase)
        public
    {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        IEtherFiNode(etherfiNode).setPhase(_phase);
    }

    /// @notice Sets the ipfs hash of the validator's encrypted private key
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _ipfs ipfs hash
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId, string calldata _ipfs)
        public
    {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        IEtherFiNode(etherfiNode).setIpfsHashForEncryptedValidatorKey(_ipfs);
    }

    function setEtherFiNodeLocalRevenueIndex(uint256 _validatorId, uint256 _localRevenueIndex) external {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        IEtherFiNode(etherfiNode).setLocalRevenueIndex(_localRevenueIndex);
    }

    function incrementNumberOfValidators(uint256 _count) external onlyStakingManagerContract {
        numberOfValidators += _count;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------


    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    function getEtherFiNodeAddress(uint256 _validatorId)
        public view
        returns (address)
    {
        return etherfiNodePerValidator[_validatorId];
    }

    function getEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId) external view returns (string memory) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        return IEtherFiNode(etherfiNode).getIpfsHashForEncryptedValidatorKey();
    }

    function generateWithdrawalCredentials(address _address) public view returns (bytes memory) {
        return abi.encodePacked(bytes1(0x01), bytes11(0x0), _address);
    }

    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        return generateWithdrawalCredentials(etherfiNode);
    }

    function getNumberOfValidators() external view returns (uint256) {
        return numberOfValidators;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == depositContract,
            "Only deposit contract function"
        );
        _;
    }
}
