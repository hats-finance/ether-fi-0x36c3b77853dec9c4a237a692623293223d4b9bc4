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
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingManager is IStakingManager, Ownable, Pausable, ReentrancyGuard {
    /// @dev please remove before mainnet deployment
    bool public test = true;
    uint128 public maxBatchDepositSize = 16;
    uint128 public stakeAmount;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;
    IEtherFiNodesManager public nodesManagerIntefaceInstance;
    mapping(uint256 => address) public bidIdToStaker;

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
        uint256 validatorId,
        string ipfsHashForEncryptedValidatorKey
    );

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev AuctionManager contract must be deployed first
    /// @param _auctionAddress the address of the auction contract for interaction
    constructor(address _auctionAddress) {
        if (test == true) {
            stakeAmount = 0.032 ether;
        } else {
            stakeAmount = 32 ether;
        }

        TNFTInterfaceInstance = ITNFT(address(new TNFT()));
        BNFTInterfaceInstance = IBNFT(address(new BNFT()));

        auctionInterfaceInstance = IAuctionManager(_auctionAddress);
        depositContractEth2 = IDepositContract(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b
        );
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------
    
    /// @notice Switches the deposit mode of the contract
    /// @dev Used for testing purposes. WILL BE DELETED BEFORE MAINNET DEPLOYMENT
    function switchMode() public {
        if (test == true) {
            test = false;
            stakeAmount = 32 ether;
        } else if (test == false) {
            test = true;
            stakeAmount = 0.032 ether;
        }
    }


    function registerTnftContract() private returns (address) {
        TNFTInterfaceInstance = ITNFT(address(new TNFT()));
        return address(TNFTInterfaceInstance);
    }

    function registerBnftContract() private returns (address) {
        BNFTInterfaceInstance = IBNFT(address(new BNFT()));
        return address(BNFTInterfaceInstance);
    }

    /// @notice Allows depositing multiple stakes at once
    /// @param _candidateBidIds IDs of the bids to be matched with each stake
    /// @return Array of the bid IDs that were processed and assigned
    function batchDepositWithBidIds(uint256[] calldata _candidateBidIds)
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
            auctionInterfaceInstance.numberOfActiveBids() >=
                numberOfDeposits,
            "No bids available at the moment"
        );

        uint256[] memory processedBidIds = new uint256[](numberOfDeposits);
        uint256 processedBidIdsCount = 0;

        for (uint256 i = 0; i < _candidateBidIds.length && processedBidIdsCount < numberOfDeposits; ++i) {
            uint256 bidId = _candidateBidIds[i];
            address bidStaker = bidIdToStaker[bidId];
            bool isActive = auctionInterfaceInstance.isBidActive(bidId);
            if (bidStaker == address(0) && isActive) {
                auctionInterfaceInstance.updateSelectedBidInformation(bidId);
                _processDeposit(bidId);
                processedBidIds[processedBidIdsCount] = bidId;
                processedBidIdsCount++;
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
    function registerValidator(uint256 _validatorId, DepositData calldata _depositData)
        public
        whenNotPaused 
    {
        require(
            nodesManagerIntefaceInstance.phase(_validatorId) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Incorrect phase"
        );
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        address staker = bidIdToStaker[_validatorId];

        //Remove this before deployment, this should always happen
        if (test = false) {
            bytes memory withdrawalCredentials = nodesManagerIntefaceInstance
                .getWithdrawalCredentials(_validatorId);
            depositContractEth2.deposit{value: stakeAmount}(
                _depositData.publicKey,
                withdrawalCredentials,
                _depositData.signature,
                _depositData.depositDataRoot
            );
        }

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
        TNFTInterfaceInstance.mint(staker, nftTokenId);
        BNFTInterfaceInstance.mint(staker, nftTokenId);

        auctionInterfaceInstance.processAuctionFeeTransfer(_validatorId);

        emit ValidatorRegistered(
            auctionInterfaceInstance.getBidOwner(_validatorId),
            _validatorId,
            _depositData.ipfsHashForEncryptedValidatorKey
        );
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function batchRegisterValidators(uint256[] calldata _validatorId, DepositData[] calldata _depositData)
        public
        whenNotPaused
    {
        require(
            _validatorId.length == _depositData.length,
            "Array lengths must match"
        );
        require(_validatorId.length <= maxBatchDepositSize, "Too many validators");

        for (uint256 x; x < _validatorId.length; ++x) {
            registerValidator(_validatorId[x], _depositData[x]);
        }
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _validatorId the ID of the validator deposit to cancel
    function cancelDeposit(uint256 _validatorId) public whenNotPaused {
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        require(
            nodesManagerIntefaceInstance.phase(_validatorId) ==
                IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Incorrect phase"
        );

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(_validatorId);

        // Mark Canceled
        nodesManagerIntefaceInstance.setEtherFiNodePhase(
            _validatorId,
            IEtherFiNode.VALIDATOR_PHASE.CANCELLED
        );

        // Unset the pointers
        bidIdToStaker[_validatorId] = address(0);
        nodesManagerIntefaceInstance.unregisterEtherFiNode(_validatorId);

        _refundDeposit(msg.sender, stakeAmount);

        emit DepositCancelled(_validatorId);

        require(bidIdToStaker[_validatorId] == address(0), "");
    }

    /// @notice Allows withdrawal of funds from contract
    /// @dev Will be removed in final version
    /// @param _wallet the address to send the funds to
    function fetchEtherFromContract(address _wallet) public onlyOwner {
        (bool sent, ) = payable(_wallet).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Sets the EtherFi node manager contract
    /// @dev Set manually due to circular dependency
    /// @param _nodesManagerAddress aaddress of the manager contract being set    
    function setEtherFiNodesManagerAddress(address _nodesManagerAddress) public onlyOwner {
        nodesManagerIntefaceInstance = IEtherFiNodesManager(_nodesManagerAddress);
    }

    /// @notice Sets the max number of deposits allowed at a time
    /// @param _newMaxBatchDepositSize the max number of deposits allowed
    function setMaxBatchDepositSize(uint128 _newMaxBatchDepositSize) public onlyOwner {
        maxBatchDepositSize = _newMaxBatchDepositSize;
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

    function uncheckedInc(uint x) private pure returns (uint) {
        unchecked {
            return x + 1;
        }
    }

    /// @notice Update the state of the contract now that a deposit has been made
    /// @param _bidId the bid that won the right to the deposit
    function _processDeposit(uint256 _bidId) internal {
        
        bidIdToStaker[_bidId] = msg.sender;

        uint256 validatorId = _bidId;
        address etherfiNode = nodesManagerIntefaceInstance.createEtherfiNode(
            validatorId
        );
        nodesManagerIntefaceInstance.setEtherFiNodePhase(
            validatorId,
            IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED
        );

        emit StakeDeposit(msg.sender, _bidId, etherfiNode);
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
}
