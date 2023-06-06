// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IProtocolRevenueManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";

contract EtherFiNodesManager is
    Initializable,
    IEtherFiNodesManager,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    uint64 public numberOfValidators;
    uint64 public nonExitPenaltyPrincipal;
    uint64 public nonExitPenaltyDailyRate;
    uint64 public SCALE;

    address public treasuryContract;
    address public stakingManagerContract;
    address public protocolRevenueManagerContract;

    mapping(uint256 => address) public etherfiNodeAddress;

    TNFT public tnft;
    BNFT public bnft;
    IAuctionManager public auctionManager;
    IProtocolRevenueManager public protocolRevenueManager;

    //Holds the data for the revenue splits depending on where the funds are received from
    RewardsSplit public stakingRewardsSplit;
    RewardsSplit public protocolRewardsSplit;

    uint256[39] public __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------
    event FundsWithdrawn(uint256 indexed _validatorId, uint256 amount);
    event NodeExitRequested(uint256 _validatorId);
    event NodeExitProcessed(uint256 _validatorId);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    /// @dev Sets the revenue splits on deployment
    /// @dev AuctionManager, treasury and deposit contracts must be deployed first
    /// @param _treasuryContract The address of the treasury contract for interaction
    /// @param _auctionContract The address of the auction contract for interaction
    /// @param _stakingManagerContract The address of the staking contract for interaction
    /// @param _tnftContract The address of the TNFT contract for interaction
    /// @param _bnftContract The address of the BNFT contract for interaction
    /// @param _protocolRevenueManagerContract The address of the protocols revenue manager contract for interaction
    function initialize(
        address _treasuryContract,
        address _auctionContract,
        address _stakingManagerContract,
        address _tnftContract,
        address _bnftContract,
        address _protocolRevenueManagerContract
    ) external initializer {
        require(_treasuryContract != address(0), "No zero addresses");
        require(_auctionContract != address(0), "No zero addresses");
        require(_stakingManagerContract != address(0), "No zero addresses");
        require(_tnftContract != address(0), "No zero addresses");
        require(_bnftContract != address(0), "No zero addresses");
        require(_protocolRevenueManagerContract != address(0), "No zero addresses"); 
               
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        nonExitPenaltyPrincipal = 1 ether;
        nonExitPenaltyDailyRate = 3; // 3% per day
        SCALE = 1_000_000;

        treasuryContract = _treasuryContract;
        stakingManagerContract = _stakingManagerContract;
        protocolRevenueManagerContract = _protocolRevenueManagerContract;

        auctionManager = IAuctionManager(_auctionContract);
        protocolRevenueManager = IProtocolRevenueManager(_protocolRevenueManagerContract);
        tnft = TNFT(_tnftContract);
        bnft = BNFT(_bnftContract);

        // in basis points for higher resolution
        stakingRewardsSplit = RewardsSplit({
            treasury: 50_000, // 5 %
            nodeOperator: 50_000, // 5 %
            tnft: 815_625, // 90 % * 29 / 32
            bnft: 84_375 // 90 % * 3 / 32
        });
        require(
            stakingRewardsSplit.treasury + stakingRewardsSplit.nodeOperator + stakingRewardsSplit.tnft + stakingRewardsSplit.bnft == SCALE,
            "Splits not equal to scale"
        );

        protocolRewardsSplit = RewardsSplit({
            treasury: 250_000, // 25 %
            nodeOperator: 250_000, // 25 %
            tnft: 453_125, // 50 % * 29 / 32
            bnft: 46_875 // 50 % * 3 / 32
        });
        require(
            protocolRewardsSplit.treasury + protocolRewardsSplit.nodeOperator + protocolRewardsSplit.tnft + protocolRewardsSplit.bnft == SCALE,
            "Splits not equal to scale"
        );
    }


    /// @notice Registers the validator ID for the EtherFiNode contract
    /// @param _validatorId ID of the validator associated to the node
    /// @param _address Address of the EtherFiNode contract
    function registerEtherFiNode(
        uint256 _validatorId,
        address _address
    ) public onlyStakingManagerContract {
        require(etherfiNodeAddress[_validatorId] == address(0), "already installed");
        etherfiNodeAddress[_validatorId] = _address;
    }

    /// @notice Unset the EtherFiNode contract for the validator ID
    /// @param _validatorId ID of the validator associated
    function unregisterEtherFiNode(
        uint256 _validatorId
    ) public onlyStakingManagerContract {
        require(etherfiNodeAddress[_validatorId] != address(0), "not installed");
        etherfiNodeAddress[_validatorId] = address(0);
    }

    /// @notice Send the request to exit the validator node
    /// @param _validatorId ID of the validator associated
    function sendExitRequest(uint256 _validatorId) public whenNotPaused {
        require(msg.sender == tnft.ownerOf(_validatorId), "You are not the owner of the T-NFT");
        require(phase(_validatorId) == IEtherFiNode.VALIDATOR_PHASE.LIVE, "validator node is not live");
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setExitRequestTimestamp();

        emit NodeExitRequested(_validatorId);
    }

    /// @notice Send the request to exit multiple nodes
    /// @param _validatorIds IDs of the validators associated
    function batchSendExitRequest(uint256[] calldata _validatorIds) external whenNotPaused {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            sendExitRequest(_validatorIds[i]);
        }
    }

    /// @notice Once the node's exit is observed, the protocol calls this function to process their exits.
    /// @param _validatorIds The list of validators which exited
    /// @param _exitTimestamps The list of exit timestamps of the validators
    function processNodeExit(
        uint256[] calldata _validatorIds,
        uint32[] calldata _exitTimestamps
    ) external onlyOwner nonReentrant whenNotPaused {
        require(_validatorIds.length == _exitTimestamps.length, "Check params");
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            _processNodeExit(_validatorIds[i], _exitTimestamps[i]);
        }
    }

    /// @notice Process the rewards skimming
    /// @param _validatorId The validator Id
    function partialWithdraw(
        uint256 _validatorId,
        bool _stakingRewards,
        bool _protocolRewards,
        bool _vestedAuctionFee
    ) public nonReentrant whenNotPaused {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        require(
            address(etherfiNode).balance < 8 ether,
            "etherfi node contract's balance is above 8 ETH. You should exit the node."
        );
        require(
            IEtherFiNode(etherfiNode).phase() != IEtherFiNode.VALIDATOR_PHASE.BEING_SLASHED,
            "you cannot perform the partial withdraw while the node is being slashed. Exit the node."
        );
        
        // Retrieve all possible rewards: {Staking, Protocol} rewards and the vested auction fee reward
        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury ) 
            = getRewardsPayouts(_validatorId, _stakingRewards, _protocolRewards, _vestedAuctionFee);

        if (_protocolRewards) {
            protocolRevenueManager.distributeAuctionRevenue(_validatorId);
        }
        if (_vestedAuctionFee) {
            IEtherFiNode(etherfiNode).processVestedAuctionFeeWithdrawal();
        }

        _distributePayouts(_validatorId, toTreasury, toOperator, toTnft, toBnft);
    }

    /// @notice Batch-process the rewards skimming
    /// @param _validatorIds A list of the validator Ids
    /// @param _stakingRewards A bool value to indictae whether or not to include the staking rewards
    /// @param _protocolRewards A bool value to indictae whether or not to include the protocol rewards
    /// @param _vestedAuctionFee A bool value to indictae whether or not to include the auction fee rewards
    function partialWithdrawBatch(
        uint256[] calldata _validatorIds,
        bool _stakingRewards,
        bool _protocolRewards,
        bool _vestedAuctionFee
    ) external whenNotPaused{
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            partialWithdraw( _validatorIds[i], _stakingRewards, _protocolRewards, _vestedAuctionFee);
        }
    }

    /// @notice Batch-process the rewards skimming for the validator nodes belonging to the same operator
    /// @param _operator The address of the operator to withdraw from
    /// @param _validatorIds The ID's of the validators to be withdrawn from
    /// @param _stakingRewards A bool value to indictae whether or not to include the staking rewards
    /// @param _protocolRewards A bool value to indictae whether or not to include the protocol rewards
    /// @param _vestedAuctionFee A bool value to indictae whether or not to include the auction fee rewards
    function partialWithdrawBatchGroupByOperator(
        address _operator,
        uint256[] memory _validatorIds,
        bool _stakingRewards,
        bool _protocolRewards,
        bool _vestedAuctionFee
    ) external nonReentrant whenNotPaused{
        uint256 totalOperatorAmount;
        uint256 totalTreasuryAmount;
        address tnftHolder;
        address bnftHolder;

        address etherfiNode;
        uint256 _validatorId;
        for (uint i = 0; i < _validatorIds.length; i++) {
            _validatorId = _validatorIds[i];
            etherfiNode = etherfiNodeAddress[_validatorId];
            require(
                _operator == auctionManager.getBidOwner(_validatorId),
                "Not bid owner"
            );
            require(
                payable(etherfiNode).balance < 8 ether,
                "etherfi node contract's balance is above 8 ETH. You should exit the node."
            );
            require(
                IEtherFiNode(etherfiNode).phase() != IEtherFiNode.VALIDATOR_PHASE.BEING_SLASHED,
                "you cannot perform the partial withdraw while the node is being slashed. Exit the node."
            );

            (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury )
                = getRewardsPayouts(_validatorId, _stakingRewards, _protocolRewards, _vestedAuctionFee);

            if (_protocolRewards) {
                protocolRevenueManager.distributeAuctionRevenue(_validatorId);
            }
            if (_vestedAuctionFee) {
                IEtherFiNode(etherfiNode).processVestedAuctionFeeWithdrawal();
            }
            IEtherFiNode(etherfiNode).moveRewardsToManager(toOperator + toTnft + toBnft + toTreasury);

            bool sent;
            tnftHolder = tnft.ownerOf(_validatorId);
            bnftHolder = bnft.ownerOf(_validatorId);
            if (tnftHolder == bnftHolder) {
                (sent, ) = payable(tnftHolder).call{value: toTnft + toBnft}("");
                require(sent, "Failed to send Ether");
            } else {
                (sent, ) = payable(tnftHolder).call{value: toTnft}("");
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
    /// @dev This fullWithdrawal is allowed only after it's marked as EXITED.
    /// @dev EtherFi will be monitoring the status of the validator nodes and mark them EXITED if they do;
    /// @dev It is a point of centralization in Phase 1
    /// @param _validatorId the validator Id to withdraw from
    function fullWithdraw(uint256 _validatorId) public nonReentrant whenNotPaused{
        address etherfiNode = etherfiNodeAddress[_validatorId];
        require(
            IEtherFiNode(etherfiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.EXITED,
            "validator node is not exited"
        );

        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) 
            = getFullWithdrawalPayouts(_validatorId);
        IEtherFiNode(etherfiNode).processVestedAuctionFeeWithdrawal();
        IEtherFiNode(etherfiNode).markFullyWithdrawn();

        _distributePayouts(_validatorId, toTreasury, toOperator, toTnft, toBnft);
    }

    /// @notice Process the full withdrawal fopr multiple validators
    /// @param _validatorIds The validator Ids
    function fullWithdrawBatch(uint256[] calldata _validatorIds) external whenNotPaused {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            fullWithdraw(_validatorIds[i]);
        }
    }

    function markBeingSlahsed(uint256[] calldata _validatorIds) external whenNotPaused onlyOwner {
        for (uint256 i = 0; i < _validatorIds.length; i++) {
            address etherfiNode = etherfiNodeAddress[_validatorIds[i]];
            IEtherFiNode(etherfiNode).markBeingSlahsed();
        }
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  SETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets the staking rewards split
    /// @notice Splits must add up to the SCALE of 1_000_000
    /// @param _treasury the split going to the treasury
    /// @param _nodeOperator the split going to the nodeOperator
    /// @param _tnft the split going to the tnft holder
    /// @param _bnft the split going to the bnft holder
    function setStakingRewardsSplit(uint64 _treasury, uint64 _nodeOperator, uint64 _tnft, uint64 _bnft)
        public onlyOwner amountsEqualScale(_treasury, _nodeOperator, _tnft, _bnft)
    {
        stakingRewardsSplit.treasury = _treasury;
        stakingRewardsSplit.nodeOperator = _nodeOperator;
        stakingRewardsSplit.tnft = _tnft;
        stakingRewardsSplit.bnft = _bnft;
    }

    /// @notice Sets the protocol rewards split
    /// @notice Splits must add up to the SCALE of 1_000_000
    /// @param _treasury the split going to the treasury
    /// @param _nodeOperator the split going to the nodeOperator
    /// @param _tnft the split going to the tnft holder
    /// @param _bnft the split going to the bnft holder
    function setProtocolRewardsSplit(uint64 _treasury, uint64 _nodeOperator, uint64 _tnft, uint64 _bnft)
        public onlyOwner amountsEqualScale(_treasury, _nodeOperator, _tnft, _bnft)
    {
        protocolRewardsSplit.treasury = _treasury;
        protocolRewardsSplit.nodeOperator = _nodeOperator;
        protocolRewardsSplit.tnft = _tnft;
        protocolRewardsSplit.bnft = _bnft;
    }

    /// @notice Sets the Non Exit Penalty Principal amount
    /// @param _nonExitPenaltyPrincipal the new principal amount
    function setNonExitPenaltyPrincipal (uint64 _nonExitPenaltyPrincipal) public onlyOwner {
        nonExitPenaltyPrincipal = _nonExitPenaltyPrincipal;
    }

    /// @notice Sets the Non Exit Penalty Daily Rate amount
    /// @param _nonExitPenaltyDailyRate the new non exit daily rate
    function setNonExitPenaltyDailyRate(uint64 _nonExitPenaltyDailyRate) public onlyOwner {
        require(_nonExitPenaltyDailyRate <= 100, "Invalid penalty rate");
        nonExitPenaltyDailyRate = _nonExitPenaltyDailyRate;
    }

    /// @notice Sets the phase of the validator
    /// @param _validatorId id of the validator associated to this etherfi node
    /// @param _phase phase of the validator
    function setEtherFiNodePhase( uint256 _validatorId, IEtherFiNode.VALIDATOR_PHASE _phase) public onlyStakingManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setPhase(_phase);
    }

    /// @notice Sets the ipfs hash of the validator's encrypted private key
    /// @param _validatorId id of the validator associated to this etherfi node
    /// @param _ipfs ipfs hash
    function setEtherFiNodeIpfsHashForEncryptedValidatorKey(uint256 _validatorId, string calldata _ipfs) 
        external onlyStakingManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setIpfsHashForEncryptedValidatorKey(_ipfs);
    }

    /// @notice Sets the local revenue index for a specific node
    /// @param _validatorId id of the validator associated to this etherfi node
    /// @param _localRevenueIndex renevue index to be set
    function setEtherFiNodeLocalRevenueIndex(uint256 _validatorId, uint256 _localRevenueIndex) external payable onlyProtocolRevenueManagerContract {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).setLocalRevenueIndex{value: msg.value}(_localRevenueIndex);
    }

    /// @notice Increments the number of validators by a certain amount
    /// @param _count how many new validators to increment by
    function incrementNumberOfValidators(uint64 _count) external onlyStakingManagerContract {
        numberOfValidators += _count;
    }

    /// TODO: remove it for mainnet deploy
    /// @notice just for testnet!
    function setNumberOfValidators(uint64 _numberOfValidators) external onlyOwner {
        numberOfValidators = _numberOfValidators;
    }

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Once the node's exit is observed, the protocol calls this function:
    ///         - mark it EXITED
    ///         - distribute the protocol (auction) revenue
    ///         - stop sharing the protocol revenue; by setting their local revenue index to '0'
    /// @param _validatorId the validator ID
    /// @param _exitTimestamp the exit timestamp
    function _processNodeExit(uint256 _validatorId, uint32 _exitTimestamp) internal {
        address etherfiNode = etherfiNodeAddress[_validatorId];

        require(IEtherFiNode(etherfiNode).phase() == IEtherFiNode.VALIDATOR_PHASE.LIVE, "Validator already exited");

        // Mark EXITED
        IEtherFiNode(etherfiNode).markExited(_exitTimestamp);

        // distribute the protocol reward from the ProtocolRevenueMgr contrac to the validator's etherfi node contract
        uint256 amount = protocolRevenueManager.distributeAuctionRevenue(_validatorId);

        // Reset its local revenue index to 0, which indicates that no accrued protocol revenue exists
        IEtherFiNode(etherfiNode).setLocalRevenueIndex(0);

        // Distribute the payouts for the protocol rewards
        (uint256 toOperator, uint256 toTnft, uint256 toBnft, uint256 toTreasury) 
            = IEtherFiNode(etherfiNode).calculatePayouts(amount, protocolRewardsSplit, SCALE);

        numberOfValidators -= 1;

        _distributePayouts(_validatorId, toTreasury, toOperator, toTnft, toBnft);

        emit NodeExitProcessed(_validatorId);
    }

    function _distributePayouts(uint256 _validatorId, uint256 _toTreasury, uint256 _toOperator, uint256 _toTnft, uint256 _toBnft) internal {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        IEtherFiNode(etherfiNode).withdrawFunds(
            treasuryContract, _toTreasury,
            auctionManager.getBidOwner(_validatorId), _toOperator,
            tnft.ownerOf(_validatorId), _toTnft,
            bnft.ownerOf(_validatorId), _toBnft
        );
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Fecthes the phase a specific node is in
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return validatorPhase the phase the node is in
    function phase(uint256 _validatorId) public view returns (IEtherFiNode.VALIDATOR_PHASE validatorPhase) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        validatorPhase = IEtherFiNode(etherfiNode).phase();
    }

    /// @notice Fecthes the ipfs hash for the encrypted key data from a specific node
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the ifs hash associated to the node
    function ipfsHashForEncryptedValidatorKey(uint256 _validatorId) external view returns (string memory) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).ipfsHashForEncryptedValidatorKey();
    }

    /// @notice Fetches the local revenue index of a specific node
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the local revenue index for the node
    function localRevenueIndex(uint256 _validatorId) external view returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).localRevenueIndex();
    }

    /// @notice Fetches the vested auction rewards of a specific node
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the vested auction rewards for the node
    function vestedAuctionRewards(uint256 _validatorId) external view returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).vestedAuctionRewards();
    }

    /// @notice Generates withdraw credentials for a validator
    /// @param _address associated with the validator for the withdraw credentials
    /// @return the generated withdraw key for the node
    function generateWithdrawalCredentials(address _address) public pure returns (bytes memory) {   
        return abi.encodePacked(bytes1(0x01), bytes11(0x0), _address);
    }

    /// @notice Fetches the withdraw credentials for a specific node
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the generated withdraw key for the node
    function getWithdrawalCredentials(uint256 _validatorId) external view returns (bytes memory) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        require(etherfiNode != address(0), "The validator Id is invalid.");
        return generateWithdrawalCredentials(etherfiNode);
    }

    /// @notice Fetches if the node has an exit request
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return bool value based on if an exit request has been sent
    function isExitRequested(uint256 _validatorId) external view returns (bool) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).exitRequestTimestamp() > 0;
    }

    /// @notice Fetches the nodes non exit penalty amount
    /// @param _validatorId id of the validator associated to etherfi node
    /// @param _endTimestamp timestamp for calculation
    /// @return the amount of the penalty
    function getNonExitPenalty(uint256 _validatorId, uint32 _endTimestamp) public view returns (uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getNonExitPenalty(nonExitPenaltyPrincipal, nonExitPenaltyDailyRate, _endTimestamp);
    }

    /// @notice Fetches the staking rewards payout for a node
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the payout for staking rewards
    function getStakingRewardsPayouts(uint256 _validatorId) 
        public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return IEtherFiNode(etherfiNode).getStakingRewardsPayouts( stakingRewardsSplit, SCALE);
    }

    /// @notice Fetches the total rewards payout for the node for specific revenues
    /// @param _validatorId ID of the validator associated to etherfi node
    /// @param _stakingRewards A bool value to indictae whether or not to include the staking rewards
    /// @param _protocolRewards A bool value to indictae whether or not to include the protocol rewards
    /// @param _vestedAuctionFee A bool value to indictae whether or not to include the auction fee rewards
    /// @return The payout for total rewards for the node
    function getRewardsPayouts(
        uint256 _validatorId,
        bool _stakingRewards,
        bool _protocolRewards,
        bool _vestedAuctionFee
    ) public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return
            IEtherFiNode(etherfiNode).getRewardsPayouts(
                _stakingRewards, _protocolRewards, _vestedAuctionFee,
                stakingRewardsSplit, SCALE,
                protocolRewardsSplit, SCALE
            );
    }

    /// @notice Fetches the full withdraw payouts
    /// @param _validatorId id of the validator associated to etherfi node
    /// @return the payout for full withdraws
    function getFullWithdrawalPayouts(uint256 _validatorId) 
        public view returns (uint256, uint256, uint256, uint256) {
        address etherfiNode = etherfiNodeAddress[_validatorId];
        return
            IEtherFiNode(etherfiNode).getFullWithdrawalPayouts(
                stakingRewardsSplit, SCALE,
                nonExitPenaltyPrincipal, nonExitPenaltyDailyRate
            );
    }

    /// @notice Fetches if the specified validator has been exited
    /// @return The bool value representing if the validator has been exited
    function isExited(uint256 _validatorId) public view returns (bool) {
        return phase(_validatorId) == IEtherFiNode.VALIDATOR_PHASE.EXITED;
    }

    /// @notice Fetches the address of the implementation contract currently being used by the proxy
    /// @return The address of the currently used implementation contract
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(msg.sender == stakingManagerContract, "Only staking manager contract function");
        _;
    }

    modifier onlyProtocolRevenueManagerContract() {
        require(msg.sender == protocolRevenueManagerContract, "Only protocol revenue manager contract function");
        _;
    }

    modifier amountsEqualScale(uint64 _treasury, uint64 _nodeOperator, uint64 _tnft, uint64 _bnft) {
        require(_treasury + _nodeOperator + _tnft + _bnft == SCALE, "Amounts not equal to 1000000");
        _;
    }
}
