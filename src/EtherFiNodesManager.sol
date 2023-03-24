// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract EtherFiNodesManager is IEtherFiNodesManager, Ownable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    uint256 private constant nonExitPenaltyPrincipal = 1 ether;
    uint256 private constant nonExitPenaltyDailyRate = 3; // 3% per day

    address public immutable implementationContract;

    uint256 public numberOfValidators;

    address public treasuryContract;
    address public auctionContract;
    address public stakingManagerContract;
    address public protocolRevenueManagerContract;

    mapping(uint256 => address) public etherfiNodeAddress;

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
    event FundsWithdrawn(uint256 indexed _validatorId, uint256 amount);
    event NodeExitRequested(uint256 _validatorId);
    event NodeExitProcessed(uint256 _validatorId);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    /// @dev Sets the revenue splits on deployment
    /// @dev AuctionManager, treasury and deposit contracts must be deployed first
    /// @param _treasuryContract the address of the treasury contract for interaction
    /// @param _auctionContract the address of the auction contract for interaction
    /// @param _stakingManagerContract the address of the deposit contract for interaction
    constructor(
        address _treasuryContract,
        address _auctionContract,
        address _stakingManagerContract,
        address _tnftContract,
        address _bnftContract,
        address _protocolRevenueManagerContract
    ) {
        implementationContract = address(new EtherFiNode());

        treasuryContract = _treasuryContract;
        auctionContract = _auctionContract;
        stakingManagerContract = _stakingManagerContract;
        protocolRevenueManagerContract = _protocolRevenueManagerContract;

        stakingManagerInstance = IStakingManager(_stakingManagerContract);
        auctionInterfaceInstance = IAuctionManager(_auctionContract);
        protocolRevenueManagerInstance = IProtocolRevenueManager(_protocolRevenueManagerContract);

        tnftInstance = TNFT(_tnftContract);
        bnftInstance = BNFT(_bnftContract);

        // in basis points for higher resolution
        stakingRewardsSplit = RewardsSplit({
            treasury: 50000, // 5 %
            nodeOperator: 50000, // 5 %
            tnft: 815625, // 90 % * 29 / 32
            bnft: 84375 // 90 % * 3 / 32
        });
        require(
            (stakingRewardsSplit.treasury + stakingRewardsSplit.nodeOperator +
                stakingRewardsSplit.tnft + stakingRewardsSplit.bnft) == SCALE,
            ""
        );

        protocolRewardsSplit = RewardsSplit({
            treasury: 250000, // 25 %
            nodeOperator: 250000, // 25 %
            tnft: 453125, // 50 % * 29 / 32 
            bnft: 46875 // 50 % * 3 / 32
        });
        require(
            (protocolRewardsSplit.treasury + protocolRewardsSplit.nodeOperator +
                protocolRewardsSplit.tnft + protocolRewardsSplit.bnft) == SCALE,
            ""
        );
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    receive() external payable {}

    function createEtherfiNode(uint256 _validatorId) external onlyStakingManagerContract returns (address) {
        address clone = Clones.clone(implementationContract);
        EtherFiNode(payable(clone)).initialize(address(protocolRevenueManagerInstance));
        registerEtherFiNode(_validatorId, clone);
        return clone;
    }

    /// @notice Sets the validator ID for the EtherFiNode contract
    /// @param _validatorId id of the validator associated to the node
    /// @param _address address of the EtherFiNode contract
    function registerEtherFiNode(uint256 _validatorId, address _address) public onlyStakingManagerContract {
        require(
            etherfiNodeAddress[_validatorId] == address(0),
            "already installed"
        );
        etherfiNodeAddress[_validatorId] = _address;
    }

    /// @notice UnSet the EtherFiNode contract for the validator ID
    /// @param _validatorId id of the validator associated
    function unregisterEtherFiNode(uint256 _validatorId) public onlyStakingManagerContract {
        require(
            etherfiNodeAddress[_validatorId] != address(0),
            "not installed"
        );
        etherfiNodeAddress[_validatorId] = address(0);
    }

    /// @notice send the request to exit the validator node
    function sendExitRequest(uint256 _validatorId) external {
        require(
            msg.sender == tnftInstance.ownerOf(_validatorId),
            "You are not the owner of the T-NFT"
        );
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setExitRequestTimestamp();

        emit NodeExitRequested(_validatorId);
    }

    /// @notice Once the node's exit is observed, the protocol calls this function:
    ///         For each node,
    ///          - mark it EXITED
    ///          - distribute the protocol (auction) revenue
    ///          - stop sharing the protocol revenue; by setting their local revenue index to '0'
    /// @param _validatorIds the list of validators which exited
    /// @param _exitTimestamps the list of exit timestamps of the validators
    function processNodeExit(uint256[] calldata _validatorIds, uint32[] calldata _exitTimestamps) external onlyOwner {
        require(_validatorIds.length == _exitTimestamps.length, "_validatorIds.length != _exitTimestamps.length");
        require(numberOfValidators >= _validatorIds.length, "Not enough validators");
        
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            uint256 validatorId = _validatorIds[i];
            address etherfiNode = etherfiNodeAddress[validatorId];

            // Mark EXITED
            IEtherFiNode(etherfiNode).markExited(_exitTimestamps[i]);
            
            // distribute the protocol reward from the ProtocolRevenueMgr contrac to the validator's etherfi node contract
            uint256 amount = protocolRevenueManagerInstance.distributeAuctionRevenue(validatorId);

            // Reset its local revenue index to 0
            IEtherFiNode(etherfiNode).setLocalRevenueIndex(0);

            // Process the payouts
            (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) 
                = IEtherFiNode(etherfiNode).calculatePayouts(amount, protocolRewardsSplit, SCALE);
            
            address operator = auctionInterfaceInstance.getBidOwner(validatorId);
            address tnftHolder = tnftInstance.ownerOf(validatorId);
            address bnftHolder = bnftInstance.ownerOf(validatorId);

            numberOfValidators -= 1;

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

            emit NodeExitProcessed(validatorId);
        }
    }

    /// @notice process the rewards skimming
    /// @param _validatorId the validator Id
    function partialWithdraw(uint256 _validatorId, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) public {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        uint256 balance = address(etherfiNode).balance;
        require(balance < 8 ether, "etherfi node contract's balance is above 8 ETH. You should exit the node.");

        // Retrieve all possible rewards: {Staking, Protocol} rewards and the vested auction fee reward
        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) 
            = getRewardsPayouts(_validatorId, _stakingRewards, _protocolRewards, _vestedAuctionFee);
        if (_protocolRewards) {
            protocolRevenueManagerInstance.distributeAuctionRevenue(_validatorId);
        }
        if (_vestedAuctionFee) {
            IEtherFiNode(etherfiNode).processVestedAuctionFeeWithdrawal();
        }

        address operator = auctionInterfaceInstance.getBidOwner(_validatorId);
        address tnftHolder = tnftInstance.ownerOf(_validatorId);
        address bnftHolder = bnftInstance.ownerOf(_validatorId);

        IEtherFiNode(etherfiNode).withdrawFunds(
            treasuryContract, toTreasury,
            operator, toOperator,
            tnftHolder, toTnft,
            bnftHolder, toBnft
        );
    }

    /// @notice batch-process the rewards skimming
    /// @param _validatorIds a list of the validator Ids
    function partialWithdraw(uint256[] calldata _validatorIds, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) external {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            partialWithdraw(_validatorIds[i], _stakingRewards, _protocolRewards, _vestedAuctionFee);
        }
    }

    /// @notice batch-process the rewards skimming for the validator nodes belonging to the same operator
    function partialWithdrawBatchGroupByOperator(address _operator, uint256[] memory _validatorIds, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) external {
        uint256 totalOperatorAmount;
        uint256 totalTreasuryAmount;
        address tnftHolder;
        address bnftHolder;

        address etherfiNode;
        uint256 _validatorId;
        for (uint i = 0; i < _validatorIds.length; i++) {
            _validatorId = _validatorIds[i];
            etherfiNode = etherfiNodeAddress[_validatorId];
            require(_operator == auctionInterfaceInstance.getBidOwner(_validatorId), "");
            require(payable(etherfiNode).balance < 8 ether, "etherfi node contract's balance is above 8 ETH. You should exit the node.");

            (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) 
                = getRewardsPayouts(_validatorId, _stakingRewards, _protocolRewards, _vestedAuctionFee);

            if (_protocolRewards) {
                protocolRevenueManagerInstance.distributeAuctionRevenue(_validatorId);
            }
            if (_vestedAuctionFee) {
                IEtherFiNode(etherfiNode).processVestedAuctionFeeWithdrawal();
            }
            IEtherFiNode(etherfiNode).moveRewardsToManager(toOperator + toTnft + toBnft + toTreasury);

            tnftHolder = tnftInstance.ownerOf(_validatorId);
            bnftHolder = bnftInstance.ownerOf(_validatorId);
            if (tnftHolder == bnftHolder) {
                (bool sent, ) = payable(tnftHolder).call{value: toTnft + toBnft}("");
                require(sent, "Failed to send Ether");
            } else {
                (bool sent, ) = payable(tnftHolder).call{value: toTnft}("");
                require(sent, "Failed to send Ether");
                (sent, ) = payable(bnftHolder).call{value: toBnft}("");
                require(sent, "Failed to send Ether");
            }
            totalOperatorAmount += toOperator;
            totalTreasuryAmount += toTreasury;
        }
        (bool sent, ) = payable(_operator).call{value: totalOperatorAmount}("");
        require(sent, "Failed to send Ether");
        (sent, ) = payable(treasuryContract).call{value: totalTreasuryAmount}("");
        require(sent, "Failed to send Ether");
    }


    /// @notice process the full withdrawal
    /// @param _validatorId the validator Id
    function fullWithdraw(uint256 _validatorId) public {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        require (address(etherfiNode).balance >= 16 ether, "not enough balance for full withdrawal");
        require (IEtherFiNode(etherfiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED, "validator node is not exited");

        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) = getFullWithdrawalPayouts(_validatorId);
        address operator = auctionInterfaceInstance.getBidOwner(_validatorId);
        address tnftHolder = tnftInstance.ownerOf(_validatorId);
        address bnftHolder = bnftInstance.ownerOf(_validatorId);

        IEtherFiNode(etherfiNode).withdrawFunds(
            treasuryContract, toTreasury,
            operator, toOperator,
            tnftHolder, toTnft,
            bnftHolder, toBnft
        );
    }

    /// @notice process the full withdrawal
    /// @param _validatorIds the validator Ids
    function fullWithdrawBatch(uint256[] calldata _validatorIds) external {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            fullWithdraw(_validatorIds[i]);
        }
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets the phase of the validator
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _phase phase of the validator
    function setEtherFiNodePhase(
        uint256 _validatorId,
        IEtherFiNode.VALIDATOR_PHASE _phase
    ) public onlyStakingManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setPhase(_phase);
    }

    /// @notice Sets the ipfs hash of the validator's encrypted private key
    /// @param _validatorId id of the validator associated to this withdraw safe
    /// @param _ipfs ipfs hash
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(
        uint256 _validatorId,
        string calldata _ipfs
    ) external onlyStakingManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setIpfsHashForEncryptedValidatorKey(_ipfs);
    }

    function setEtherFiNodeLocalRevenueIndex(
        uint256 _validatorId,
        uint256 _localRevenueIndex
    ) payable external onlyProtocolRevenueManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setLocalRevenueIndex{value: msg.value}(_localRevenueIndex);
    }

    function incrementNumberOfValidators(
        uint256 _count
    ) external onlyStakingManagerContract {
        numberOfValidators += _count;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    function phase(uint256 _validatorId) public view returns (IEtherFiNode.VALIDATOR_PHASE phase) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        phase = IEtherFiNode(etherfiNode).phase();
    }

    function ipfsHashForEncryptedValidatorKey(uint256 _validatorId) external view returns (string memory) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).ipfsHashForEncryptedValidatorKey();
    }

    function localRevenueIndex(uint256 _validatorId) external view returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).localRevenueIndex();
    }

    function vestedAuctionRewards(uint256 _validatorId) external returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).vestedAuctionRewards();
    }

    function generateWithdrawalCredentials(address _address) public pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x01), bytes11(0x0), _address);
    }

    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return generateWithdrawalCredentials(etherfiNode);
    }

    function isExitRequested(uint256 _validatorId) external view returns (bool) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).exitRequestTimestamp() > 0;
    }

    function getNonExitPenalty(uint256 _validatorId, uint32 _endTimestamp) public view returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getNonExitPenalty(nonExitPenaltyPrincipal, nonExitPenaltyDailyRate, _endTimestamp);
    }

    function getStakingRewardsPayouts(uint256 _validatorId) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getStakingRewardsPayouts(stakingRewardsSplit, SCALE);
    }

    function getRewardsPayouts(uint256 _validatorId, bool _stakingRewards, bool _protocolRewards, bool _vestedAuctionFee) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getRewardsPayouts(_stakingRewards, _protocolRewards, _vestedAuctionFee, stakingRewardsSplit, SCALE, protocolRewardsSplit, SCALE);
    }

    function getFullWithdrawalPayouts(uint256 _validatorId) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getFullWithdrawalPayouts(stakingRewardsSplit, SCALE, nonExitPenaltyPrincipal, nonExitPenaltyDailyRate);
    }

    function isExited(uint256 _validatorId) external view returns (bool) {
        return phase(_validatorId) == IEtherFiNode.VALIDATOR_PHASE.EXITED;
    }


    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContract,
            "Only staking manager contract function"
        );
        _;
    }

    modifier onlyProtocolRevenueManagerContract() {
        require(
            msg.sender == protocolRevenueManagerContract,
            "Only protocol revenue manager contract function"
        );
        _;
    }
}
