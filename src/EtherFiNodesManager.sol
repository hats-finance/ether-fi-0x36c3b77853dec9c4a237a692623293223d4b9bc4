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
    uint256 private constant nonExitPenaltyPrincipal = 1 ether;
    uint256 private constant nonExitPenaltyDailyRate = 3; // 3% per day

    address public immutable implementationContract;

    uint256 public numberOfValidators;

    address public owner;
    address public treasuryContract;
    address public auctionContract;
    address public depositContract;

    mapping(uint256 => address) public etherfiNodePerValidator;

    TNFT public tnftInstance;
    BNFT public bnftInstance;
    IStakingManager public stakingManagerInstance;
    IAuctionManager public auctionInterfaceInstance;
    IProtocolRevenueManager public protocolRevenueManagerInstance;

    //Holds the data for the revenue splits depending on where the funds are received from
    uint256 public constant SCALE = 1000000;
    RewardsSplit public stakingRewardsSplit;
    RewardsSplit public protocolRewardsSplit;

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
        address _bnftContract,
        address _protocolRevenueManagerContract
    ) {
        implementationContract = address(new EtherFiNode());

        owner = msg.sender;
        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;
        depositContract = _depositContract;

        stakingManagerInstance = IStakingManager(_depositContract);
        auctionInterfaceInstance = IAuctionManager(_auctionContract);
        protocolRevenueManagerInstance = IProtocolRevenueManager(_protocolRevenueManagerContract);

        tnftInstance = TNFT(_tnftContract);
        bnftInstance = BNFT(_bnftContract);

        // in basis points for higher resolution
        stakingRewardsSplit = RewardsSplit({
            treasury: 50000,
            nodeOperator: 50000,
            tnft: 815625, // 90 * 29 / 32
            bnft: 84375 // 90 * 3 / 32
        });
        require(
            (stakingRewardsSplit.treasury +
                stakingRewardsSplit.nodeOperator +
                stakingRewardsSplit.tnft +
                stakingRewardsSplit.bnft) == SCALE,
            ""
        );

        protocolRewardsSplit = RewardsSplit({
            treasury: 250000,
            nodeOperator: 250000,
            tnft: 453125,
            bnft: 46875
        });
        require(
            (protocolRewardsSplit.treasury +
                protocolRewardsSplit.nodeOperator +
                protocolRewardsSplit.tnft +
                protocolRewardsSplit.bnft) == SCALE,
            ""
        );
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function createEtherfiNode(
        uint256 _validatorId
    ) external returns (address) {
        address clone = Clones.clone(implementationContract);
        EtherFiNode(payable(clone)).initialize(address(protocolRevenueManagerInstance));
        installEtherFiNode(_validatorId, clone);
        return clone;
    }

    /// @notice process the rewards skimming
    /// @param _validatorId the validator Id
    function partialWithdraw(uint256 _validatorId) external {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");

        uint256 balance = address(etherfiNode).balance;
        require(balance < 8 ether, "The accrued staking rewards are above 8 ETH. You should exit the node.");

        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = getRewards(_validatorId, true, true, true);
        protocolRevenueManagerInstance.distributeAuctionRevenue(_validatorId);
        IEtherFiNode(etherfiNode).updateAfterPartialWithdrawal(true);

        address operator = auctionInterfaceInstance.getBidOwner(_validatorId);
        address tnftHolder = tnftInstance.ownerOf(_validatorId);
        address bnftHolder = bnftInstance.ownerOf(_validatorId);

        IEtherFiNode(etherfiNode).withdrawFunds(
            treasuryContract,
            toTreasury,
            operator,
            toOperator,
            tnftHolder,
            toTnft,
            bnftHolder,
            toBnft
        );
    }

    /// @notice process the full withdrawal
    /// @param _validatorId the validator Id
    function fullWithdraw(uint256 _validatorId) external {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");

        uint256 balance = IEtherFiNode(etherfiNode).getWithdrawableBalance();
        IEtherFiNode.VALIDATOR_PHASE phase = IEtherFiNode(etherfiNode).phase();
        require (balance >= 16 ether, "not enough balance for full withdrawal");
        require (phase == IEtherFiNode.VALIDATOR_PHASE.EXITED, "validator node is not exited");

        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = getFullWithdrawalPayouts(_validatorId);
        address operator = auctionInterfaceInstance.getBidOwner(_validatorId);
        address tnftHolder = tnftInstance.ownerOf(_validatorId);
        address bnftHolder = bnftInstance.ownerOf(_validatorId);

        IEtherFiNode(etherfiNode).withdrawFunds(
            treasuryContract,
            toTreasury,
            operator,
            toOperator,
            tnftHolder,
            toTnft,
            bnftHolder,
            toBnft
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

    function markExited(uint256[] calldata _validatorIds, uint32[] calldata _exitTimestamps) external onlyOwner {
        require(_validatorIds.length == _exitTimestamps.length, "_validatorIds.length != _exitTimestamps.length");
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            address etherfiNode = etherfiNodePerValidator[_validatorIds[i]];
            require(etherfiNode != address(0), "The validator Id is invalid.");
            IEtherFiNode(etherfiNode).markExited(_exitTimestamps[i]);
        }
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

    function getEtherFiNodePhase(
        uint256 _validatorId
    ) public view returns (IEtherFiNode.VALIDATOR_PHASE phase) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        phase = IEtherFiNode(etherfiNode).phase();
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

    function getEtherFiNodeVestedAuctionRewards(
        uint256 _validatorId
    ) external returns (uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).vestedAuctionRewards();
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
        return getNonExitPenaltyAmount(_validatorId, uint32(block.timestamp));
    }

    function getNonExitPenaltyAmount(
        uint256 _validatorId,
        uint32 _endTimestamp
    ) public view returns (uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).getNonExitPenaltyAmount(nonExitPenaltyPrincipal, nonExitPenaltyDailyRate, _endTimestamp);
    }

    function getStakingRewards(uint256 _validatorId) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).getStakingRewards(stakingRewardsSplit, SCALE);
    }

    function getRewards(uint256 _validatorId, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).getRewards(_stakingRewards, _protocolRewards, _vestedAuctionFee, stakingRewardsSplit, SCALE, protocolRewardsSplit, SCALE);
    }

    function getFullWithdrawalPayouts(uint256 _validatorId) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodePerValidator[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return IEtherFiNode(etherfiNode).getFullWithdrawalPayouts(stakingRewardsSplit, SCALE, nonExitPenaltyPrincipal, nonExitPenaltyDailyRate);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == depositContract,
            "Only deposit contract function"
        );
        _;
    }
}
