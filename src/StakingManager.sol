// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./interfaces/IProtocolRevenueManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "lib/forge-std/src/console.sol";

contract StakingManager is IStakingManager, Ownable, Pausable, ReentrancyGuard {
    /// @dev please remove before mainnet deployment
    bool public test = true;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;
    IEtherFiNodesManager public nodesManagerIntefaceInstance;
    IProtocolRevenueManager protocolRevenueManager;

    uint256 public stakeAmount;
    address public treasuryAddress;
    address public auctionAddress;
    address public nodesManagerAddress;

    address public tnftContractAddress;
    address public bnftContractAddress;

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

        registerTnftContract();
        registerBnftContract();

        auctionInterfaceInstance = IAuctionManager(_auctionAddress);
        depositContractEth2 = IDepositContract(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b
        );
        auctionAddress = _auctionAddress;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

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
        tnftContractAddress = address(new TNFT());
        TNFTInterfaceInstance = ITNFT(tnftContractAddress);
        return tnftContractAddress;
    }

    function registerBnftContract() private returns (address) {
        bnftContractAddress = address(new BNFT());
        BNFTInterfaceInstance = IBNFT(bnftContractAddress);
        return bnftContractAddress;
    }

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
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >=
                numberOfDeposits,
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
                processDeposit(bidId);
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
    function registerValidator(
        uint256 _validatorId,
        DepositData calldata _depositData
    ) public whenNotPaused {
        require(
            bidIdToStaker[_validatorId] != address(0),
            "Deposit does not exist"
        );
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        address staker = bidIdToStaker[_validatorId];

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
    function batchRegisterValidators(
        uint256[] calldata _validatorId,
        DepositData[] calldata _depositData
    ) public whenNotPaused {
        require(
            _validatorId.length == _depositData.length,
            "Array lengths must match"
        );
        require(_validatorId.length <= 16, "Too many validators");

        for (uint256 x; x < _validatorId.length; ++x) {
            registerValidator(_validatorId[x], _depositData[x]);
        }
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _validatorId the ID of the validator deposit to cancel
    function cancelDeposit(uint256 _validatorId) public whenNotPaused {
        require(
            bidIdToStaker[_validatorId] != address(0),
            "Deposit does not exist"
        );
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");

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
        nodesManagerIntefaceInstance.uninstallEtherFiNode(_validatorId);

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

    function setEtherFiNodesManagerAddress(
        address _nodesManagerAddress
    ) public onlyOwner {
        nodesManagerAddress = _nodesManagerAddress;
        nodesManagerIntefaceInstance = IEtherFiNodesManager(
            nodesManagerAddress
        );
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyOwner {
        treasuryAddress = _treasuryAddress;
    }

    function setProtocolRevenueManager(
        address _protocolRevenueManager
    ) public onlyOwner {
        protocolRevenueManager = IProtocolRevenueManager(
            _protocolRevenueManager
        );
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

    function processDeposit(uint256 _bidId) internal {
        // Take the bid; Set the matched staker for the bid
        bidIdToStaker[_bidId] = msg.sender;

        // Let validatorId = BidId
        uint256 validatorId = _bidId;

        // Create the node contract
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
