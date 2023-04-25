// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./EtherFiNode.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin-upgradeable/contracts/proxy/beacon/IBeaconUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "forge-std/console.sol";

contract StakingManager is
    Initializable,
    IStakingManager,
    IBeaconUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    
    uint128 public maxBatchDepositSize;
    uint128 public stakeAmount;

    address public implementationContract;
    address public liquidityPoolContract;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;
    IEtherFiNodesManager public nodesManagerIntefaceInstance;
    UpgradeableBeacon private upgradableBeacon;

    mapping(uint256 => address) public bidIdToStaker;

    uint256[40] public __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event StakeDeposit(
        address indexed staker,
        uint256 bidId,
        address withdrawSafe
    );
    event DepositCancelled(uint256 id);
    event ValidatorRegistered(
        address indexed operator,
        address indexed bNftOwner,
        address indexed tNftOwner,
        uint256 validatorId,
        bytes validatorPubKey,
        string ipfsHashForEncryptedValidatorKey
    );

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice initialize to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev AuctionManager contract must be deployed first
    /// @param _auctionAddress the address of the auction contract for interaction
    function initialize(address _auctionAddress) external initializer {
         
        stakeAmount = 32 ether;
        maxBatchDepositSize = 25;

        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        auctionInterfaceInstance = IAuctionManager(_auctionAddress);
        depositContractEth2 = IDepositContract(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b
        );
    }

    /// @notice Allows depositing multiple stakes at once
    /// @param _candidateBidIds IDs of the bids to be matched with each stake
    /// @return Array of the bid IDs that were processed and assigned
    function batchDepositWithBidIds(
        uint256[] calldata _candidateBidIds
    )
        external
        payable
        whenNotPaused
        correctStakeAmount
        nonReentrant
        returns (uint256[] memory)
    {
        require(_candidateBidIds.length > 0, "No bid Ids provided");
        uint256 numberOfDeposits = msg.value / stakeAmount;
        require(numberOfDeposits <= maxBatchDepositSize, "Batch too large");
        require(
            auctionInterfaceInstance.numberOfActiveBids() >= numberOfDeposits,
            "No bids available at the moment"
        );

        uint256[] memory processedBidIds = new uint256[](numberOfDeposits);
        uint256 processedBidIdsCount = 0;

        for (
            uint256 i = 0;
            i < _candidateBidIds.length &&
                processedBidIdsCount < numberOfDeposits;
            ++i
        ) {
            uint256 bidId = _candidateBidIds[i];
            address bidStaker = bidIdToStaker[bidId];
            bool isActive = auctionInterfaceInstance.isBidActive(bidId);
            if (bidStaker == address(0) && isActive) {
                auctionInterfaceInstance.updateSelectedBidInformation(bidId);
                processedBidIds[processedBidIdsCount] = bidId;
                processedBidIdsCount++;
                _processDeposit(bidId);
            }
        }

        //resize the processedBidIds array to the actual number of processed bid IDs
        assembly {
            mstore(processedBidIds, processedBidIdsCount)
        }

        uint256 unMatchedBidCount = numberOfDeposits - processedBidIdsCount;
        if (unMatchedBidCount > 0) {
            _refundDeposit(msg.sender, stakeAmount * unMatchedBidCount);
        }

        return processedBidIds;
    }


    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    /// however, instead of the validator key, it will include the IPFS hash
    /// containing the validator key encrypted by the corresponding node operator's public key
    function registerValidator(
        bytes32 _depositRoot,
        uint256 _validatorId,
        DepositData calldata _depositData
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {        
        return _registerValidator(_validatorId, msg.sender, msg.sender, _depositData);
    }

    function registerValidator(
        bytes32 _depositRoot,
        uint256 _validatorId,
        address _bNftRecipient, 
        address _tNftRecipient,
        DepositData calldata _depositData
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {        
        return _registerValidator(_validatorId, _bNftRecipient, _tNftRecipient, _depositData);
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function batchRegisterValidators(
        bytes32 _depositRoot,
        uint256[] calldata _validatorId,
        DepositData[] calldata _depositData
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {
        require(_validatorId.length == _depositData.length, "Array lengths must match");
        require(_validatorId.length <= maxBatchDepositSize, "Too many validators");

        for (uint256 x; x < _validatorId.length; ++x) {
            _registerValidator(_validatorId[x], msg.sender, msg.sender, _depositData[x]);    
        }  
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function batchRegisterValidators(
        bytes32 _depositRoot,
        uint256[] calldata _validatorId,
        address _bNftRecipient, 
        address _tNftRecipient,
        DepositData[] calldata _depositData
    ) public whenNotPaused nonReentrant verifyDepositState(_depositRoot) {
        require(_validatorId.length == _depositData.length, "Array lengths must match");
        require(_validatorId.length <= maxBatchDepositSize, "Too many validators");

        for (uint256 x; x < _validatorId.length; ++x) {
            _registerValidator(_validatorId[x],_bNftRecipient, _tNftRecipient, _depositData[x]);    
        }  
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _validatorId the ID of the validator deposit to cancel
    function cancelDeposit(
        uint256 _validatorId
    ) public whenNotPaused nonReentrant {
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        require(
            nodesManagerIntefaceInstance.phase(_validatorId) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Incorrect phase"
        );

        bidIdToStaker[_validatorId] = address(0);

        // Mark Canceled
        nodesManagerIntefaceInstance.setEtherFiNodePhase(
            _validatorId,
            IEtherFiNode.VALIDATOR_PHASE.CANCELLED
        );

        // Unset the pointers
        nodesManagerIntefaceInstance.unregisterEtherFiNode(_validatorId);

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(_validatorId);
        _refundDeposit(msg.sender, stakeAmount);

        emit DepositCancelled(_validatorId);

        require(bidIdToStaker[_validatorId] == address(0), "Bid already cancelled");
    }

    /// @notice Sets the EtherFi node manager contract
    /// @dev Set manually due to circular dependency
    /// @param _nodesManagerAddress aaddress of the manager contract being set
    function setEtherFiNodesManagerAddress(
        address _nodesManagerAddress
    ) public onlyOwner {
        nodesManagerIntefaceInstance = IEtherFiNodesManager(
            _nodesManagerAddress
        );
    }

    /// @notice Sets the Liquidity pool contract address
    /// @dev Set manually due to circular dependency
    /// @param _liquidityPoolAddress aaddress of the liquidity pool contract being set
    function setLiquidityPoolAddress(
        address _liquidityPoolAddress
    ) public onlyOwner {
        liquidityPoolContract = _liquidityPoolAddress;
    }

    /// @notice Sets the max number of deposits allowed at a time
    /// @param _newMaxBatchDepositSize the max number of deposits allowed
    function setMaxBatchDepositSize(
        uint128 _newMaxBatchDepositSize
    ) public onlyOwner {
        maxBatchDepositSize = _newMaxBatchDepositSize;
    }

    function registerEtherFiNodeImplementationContract(
        address _etherFiNodeImplementationContract
    ) public onlyOwner {
        implementationContract = _etherFiNodeImplementationContract;
        upgradableBeacon = new UpgradeableBeacon(implementationContract);      
    }

    function registerTNFTContract(address _tnftAddress) public onlyOwner {
        TNFTInterfaceInstance = ITNFT(_tnftAddress);
    }

    function registerBNFTContract(address _bnftAddress) public onlyOwner {
        BNFTInterfaceInstance = IBNFT(_bnftAddress);
    }

    function upgradeEtherFiNode(address _newImplementation) public onlyOwner {
        upgradableBeacon.upgradeTo(_newImplementation);
        implementationContract = _newImplementation;
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

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _bNftRecipient the address to receive the minted B-NFT
    /// @param _tNftRecipient the address to receive the minted T-NFT
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    /// however, instead of the validator key, it will include the IPFS hash
    /// containing the validator key encrypted by the corresponding node operator's public key
    function _registerValidator(
        uint256 _validatorId,
        address _bNftRecipient, 
        address _tNftRecipient,
        DepositData calldata _depositData
    ) internal {
        require(
            nodesManagerIntefaceInstance.phase(_validatorId) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Incorrect phase"
        );
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        address staker = bidIdToStaker[_validatorId];

        
        bytes memory withdrawalCredentials = nodesManagerIntefaceInstance
            .getWithdrawalCredentials(_validatorId);
        
        // Deposit to the Beacon Chain
        depositContractEth2.deposit{value: stakeAmount}(
            _depositData.publicKey,
            withdrawalCredentials,
            _depositData.signature,
            _depositData.depositDataRoot
        );
    

        nodesManagerIntefaceInstance.incrementNumberOfValidators(1);
        nodesManagerIntefaceInstance.setEtherFiNodePhase(
            _validatorId,
            IEtherFiNode.VALIDATOR_PHASE.LIVE
        );
        nodesManagerIntefaceInstance
            .setEtherFiNodeIpfsHashForEncryptedValidatorKey(
                _validatorId,
                _depositData.ipfsHashForEncryptedValidatorKey
            );

        // Let valiadatorId = nftTokenId
        // Mint {T, B}-NFTs to the Staker
        uint256 nftTokenId = _validatorId;
        TNFTInterfaceInstance.mint(_tNftRecipient, nftTokenId);
        BNFTInterfaceInstance.mint(_bNftRecipient, nftTokenId);

        auctionInterfaceInstance.processAuctionFeeTransfer(_validatorId);

        emit ValidatorRegistered(
            auctionInterfaceInstance.getBidOwner(_validatorId),
            _bNftRecipient,
            _tNftRecipient,
            _validatorId,
            _depositData.publicKey,
            _depositData.ipfsHashForEncryptedValidatorKey
        );
    }

    /// @notice Update the state of the contract now that a deposit has been made
    /// @param _bidId the bid that won the right to the deposit
    function _processDeposit(uint256 _bidId) internal {
        bidIdToStaker[_bidId] = msg.sender;

        uint256 validatorId = _bidId;
        address etherfiNode = createEtherfiNode(validatorId);
        nodesManagerIntefaceInstance.setEtherFiNodePhase(
            validatorId,
            IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        emit StakeDeposit(msg.sender, _bidId, etherfiNode);
    }

    function createEtherfiNode(uint256 _validatorId) private returns (address) {
        BeaconProxy proxy = new BeaconProxy(address(upgradableBeacon), "");
        EtherFiNode node = EtherFiNode(address(proxy));
        node.initialize(address(nodesManagerIntefaceInstance));
        nodesManagerIntefaceInstance.registerEtherFiNode(
            _validatorId,
            address(node)
        );

        return address(node);
    }

    /// @notice Refunds the depositor their staked ether for a specific stake
    /// @dev Gets called internally from cancelStakingManager or when the time runs out for calling registerValidator
    /// @param _depositOwner address of the user being refunded
    /// @param _amount the amount to refund the depositor
    function _refundDeposit(address _depositOwner, uint256 _amount) internal {
        //Refund the user with their requested amount
        (bool sent, ) = _depositOwner.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function implementation() public view override returns (address) {
        return upgradableBeacon.implementation();
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier correctStakeAmount() {
        require(
            msg.value > 0 && msg.value % stakeAmount == 0,
            "Insufficient staking amount"
        );
        _;
    }

    modifier verifyDepositState(bytes32 _depositRoot) {
        bytes32 onchainDepositRoot = depositContractEth2.get_deposit_root();
        require(_depositRoot == onchainDepositRoot, "deposit root changed");
        _;
    }
}
