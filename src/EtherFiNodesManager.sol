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
    uint256 private constant NON_EXIT_PENALTY_PRINCIPAL = 1 ether;
    uint256 private constant NON_EXIT_PENALTY_RATE_DAILY = 3; // 3% per day
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant DAYS_PER_WEEK = 7;

    address public immutable implementationContract;

    uint256 public constant SCALE = 100;

    uint256 public numberOfValidators;

    address public owner;
    address public treasuryContract;
    address public auctionContract;
    address public depositContract;

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
    event NodeExitRequested(uint256 _validatorId);

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
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function createEtherfiNode(
        uint256 _validatorId
    ) external returns (address) {
        address clone = Clones.clone(implementationContract);
        EtherFiNode(payable(clone)).initialize();
        installEtherFiNode(_validatorId, clone);
        return clone;
    }

    /// @notice updates claimable balances based on funds received from validator and distributes the funds
    /// @dev Need to think about distribution if there has been slashing
    function withdrawFunds(uint256 _validatorId) external {
        require(
            msg.sender == stakingManagerInstance.bidIdToStaker(_validatorId),
            "Incorrect caller"
        );
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets the validator ID for the EtherFiNode contract
    /// @param _validatorId id of the validator associated to the node
    /// @param _etherfiNode address of the EtherFiNode contract
    function installEtherFiNode(
        uint256 _validatorId,
        address _etherfiNode
    ) public onlyStakingManagerContract {
        require(
            etherfiNodePerValidator[_validatorId] == address(0),
            "already installed"
        );
        etherfiNodePerValidator[_validatorId] = _etherfiNode;
    }

    /// @notice UnSet the EtherFiNode contract for the validator ID
    /// @param _validatorId id of the validator associated
    function uninstallEtherFiNode(
        uint256 _validatorId
    ) public onlyStakingManagerContract {
        require(
            etherfiNodePerValidator[_validatorId] != address(0),
            "not installed"
        );
        etherfiNodePerValidator[_validatorId] = address(0);
    }

    /// @notice Sets the phase of the validator
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _phase phase of the validator
    function setEtherFiNodePhase(
        uint256 _validatorId,
        IEtherFiNode.VALIDATOR_PHASE _phase
    ) public {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        IEtherFiNode(etherfiNode).setPhase(_phase);
    }

    /// @notice Sets the ipfs hash of the validator's encrypted private key
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _ipfs ipfs hash
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId,
        string calldata _ipfs
    ) public {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        IEtherFiNode(etherfiNode).setIpfsHashForEncryptedValidatorKey(_ipfs);
    }

    function setEtherFiNodeLocalRevenueIndex(
        uint256 _validatorId,
        uint256 _localRevenueIndex
    ) external {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        IEtherFiNode(etherfiNode).setLocalRevenueIndex(_localRevenueIndex);
    }

    function incrementNumberOfValidators(
        uint256 _count
    ) external onlyStakingManagerContract {
        numberOfValidators += _count;
    }

    /// @notice send the request to exit the validator node
    function sendExitRequest(uint256 _validatorId) external {
        require(
            msg.sender == tnftInstance.ownerOf(_validatorId),
            "You are not the owner of the T-NFT"
        );
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        IEtherFiNode(etherfiNode).setExitRequestTimestamp();

        emit NodeExitRequested(_validatorId);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    function getEtherFiNodeAddress(
        uint256 _validatorId
    ) public view returns (address) {
        return etherfiNodePerValidator[_validatorId];
    }

    function getEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId
    ) external view returns (string memory) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).ipfsHashForEncryptedValidatorKey();
    }

    function getEtherFiNodeLocalRevenueIndex(
        uint256 _validatorId
    ) external view returns (uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).localRevenueIndex();
    }

    function generateWithdrawalCredentials(
        address _address
    ) public pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x01), bytes11(0x0), _address);
    }

    function getWithdrawalCredentials(
        uint256 _validatorId
    ) external view returns (bytes memory) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return generateWithdrawalCredentials(etherfiNode);
    }

    function getNumberOfValidators() external view returns (uint256) {
        return numberOfValidators;
    }

    function isExitRequested(
        uint256 _validatorId
    ) external view returns (bool) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).exitRequestTimestamp() > 0;
    }

    function getNonExitPenaltyAmount(
        uint256 _validatorId
    ) external view returns (uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");

        uint64 startTimestamp = IEtherFiNode(etherfiNode)
            .exitRequestTimestamp();
        uint64 endTimestamp = uint64(block.timestamp);
        uint64 timeElapsed = endTimestamp - startTimestamp;
        uint64 daysElapsed = uint64(timeElapsed / SECONDS_PER_DAY);
        uint64 weeksElapsed = uint64(daysElapsed / DAYS_PER_WEEK);

        uint256 remainingAmount = NON_EXIT_PENALTY_PRINCIPAL;
        if (daysElapsed > 365) {
            remainingAmount = 0;
        } else {
            for (uint64 i = 0; i < weeksElapsed; i++) {
                remainingAmount =
                    (remainingAmount *
                        (100 - NON_EXIT_PENALTY_RATE_DAILY) ** DAYS_PER_WEEK) /
                    (100 ** DAYS_PER_WEEK);
            }

            daysElapsed -= weeksElapsed * 7;
            for (uint64 i = 0; i < daysElapsed; i++) {
                remainingAmount =
                    (remainingAmount * (100 - NON_EXIT_PENALTY_RATE_DAILY)) /
                    100;
            }
        }

        uint256 penaltyAmount = NON_EXIT_PENALTY_PRINCIPAL - remainingAmount;
        require(
            penaltyAmount <= NON_EXIT_PENALTY_PRINCIPAL && penaltyAmount >= 0,
            "Incorrect penalty amount"
        );

        return penaltyAmount;
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
