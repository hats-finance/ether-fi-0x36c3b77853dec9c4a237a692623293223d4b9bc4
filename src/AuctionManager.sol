// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//Importing all needed contracts and libraries
import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IStakingManager.sol";
import "./interfaces/IAuctionManager.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IEtherFiNode.sol";
import "./interfaces/IEtherFiNodesManager.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./StakingManager.sol";
import "../src/NodeOperatorKeyManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AuctionManager is IAuctionManager, Pausable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public currentHighestBidId;
    uint256 public whitelistBidAmount = 0.001 ether;
    uint256 public minBidAmount = 0.01 ether;
    uint256 public constant MAX_BID_AMOUNT = 5 ether;
    uint256 public numberOfBids = 1;
    uint256 public numberOfActiveBids;
    address public stakingManagerContractAddress;
    address public owner;
    address public withdrawSafeManager;
    address public nodeOperatorKeyManagerContract;
    bytes32 public merkleRoot;

    IEtherFiNode public safeInstance;

    mapping(uint256 => Bid) public bids;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event BidPlaced(
        address indexed bidder,
        uint256 amount,
        uint256 indexed bidId,
        uint256 indexed pubKeyIndex
    );

    event WinningBidSent(address indexed winner, uint256 indexed highestBidId);
    event BidReEnteredAuction(uint256 indexed bidId);
    event BiddingEnabled();
    event BidCancelled(uint256 indexed bidId);
    event BidUpdated(uint256 indexed bidId, uint256 valueUpdatedBy);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);
    event StakingManagerAddressSet(address indexed stakingManagerContractAddress);
    event MinBidUpdated(
        uint256 indexed oldMinBidAmount,
        uint256 indexed newMinBidAmount
    );
    event WhitelistBidUpdated(
        uint256 indexed oldBidAmount,
        uint256 indexed newBidAmount
    );
    event Received(address indexed sender, uint256 value);
    event FundsSentToEtherFiNode(uint256 indexed _amount);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    constructor(address _nodeOperatorKeyManagerContract) {
        owner = msg.sender;
        nodeOperatorKeyManagerContract = _nodeOperatorKeyManagerContract;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice calculates the winning operator bid when a stake is deposited
    /// @dev Used local variables to prevent multiple calling of state variables to save gas
    /// @dev Gets called from the deposit contract when a stake is received
    /// @return winningOperator the address of the current highest bidder
    function calculateWinningBid()
        external
        onlyStakingManagerContract
        returns (uint256)
    {
        uint256 currentHighestBidIdLocal = currentHighestBidId;
        uint256 numberOfBidsLocal = numberOfBids;

        //Set the bid to be de-activated to prevent 1 bid winning twice
        bids[currentHighestBidIdLocal].isActive = false;

        address winningOperator = bids[currentHighestBidIdLocal].bidderAddress;

        uint256 tempWinningBidId;
        //Loop to calculate the next highest bid for the next stake
        for (uint256 x = 1; x < numberOfBidsLocal; ++x) {
            if (
                (bids[x].isActive == true) &&
                (bids[x].amount > bids[tempWinningBidId].amount)
            ) {
                tempWinningBidId = x;
            }
        }
        currentHighestBidId = tempWinningBidId;

        numberOfActiveBids--;

        emit WinningBidSent(winningOperator, currentHighestBidIdLocal);
        return currentHighestBidIdLocal;
    }

    /// @notice Cancels a specified bid by de-activating it
    /// @dev Used local variables to save on multiple state variable lookups
    /// @dev First require checks both if the bid doesnt exist and if its called by incorrect owner
    /// @param _bidId the ID of the bid to cancel
    function cancelBid(uint256 _bidId) external whenNotPaused {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        //Set local variable for read operations to save gas
        uint256 numberOfBidsLocal = numberOfBids;

        //Cancel the bid by de-activating it
        bids[_bidId].isActive = false;

        //Check if the bid being cancelled is the current highest to make sure we
        //Calculate a new highest
        if (currentHighestBidId == _bidId) {
            uint256 tempWinningBidId;

            //Calculate the new highest bid
            for (uint256 x = 1; x < numberOfBidsLocal; ++x) {
                if (
                    (bids[x].amount > bids[tempWinningBidId].amount) &&
                    (bids[x].isActive == true)
                ) {
                    tempWinningBidId = x;
                }
            }

            currentHighestBidId = tempWinningBidId;
        }

        //Get the value of the cancelled bid to refund
        uint256 bidValue = bids[_bidId].amount;

        //Refund the user with their bid amount
        (bool sent, ) = msg.sender.call{value: bidValue}("");
        require(sent, "Failed to send Ether");

        numberOfActiveBids--;

        emit BidCancelled(_bidId);
    }

    /// @notice Places a bid in the auction to be the next operator
    /// @dev Merkleroot gets generated in JS offline and sent to the contract
    /// @param _merkleProof the merkleproof for the user calling the function
    function bidOnStake(bytes32[] calldata _merkleProof)
        external
        payable
        whenNotPaused
    {
        // Checks if bidder is on whitelist
        if (msg.value < minBidAmount) {
            require(
                MerkleProof.verify(
                    _merkleProof,
                    merkleRoot,
                    keccak256(abi.encodePacked(msg.sender))
                ) && msg.value >= whitelistBidAmount,
                "Invalid bid"
            );
        } else {
            require(msg.value <= MAX_BID_AMOUNT, "Invalid bid");
        }

        uint256 nextAvailableIpfsIndex = NodeOperatorKeyManager(
            nodeOperatorKeyManagerContract
        ).numberOfKeysUsed(msg.sender);
        NodeOperatorKeyManager(nodeOperatorKeyManagerContract)
            .increaseKeysIndex(msg.sender);

        //Creates a bid object for storage and lookup in future
        bids[numberOfBids] = Bid({
            amount: msg.value,
            bidderPubKeyIndex: nextAvailableIpfsIndex,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender,
            isActive: true
        });

        //Checks if the bid is now the highest bid
        if (msg.value > bids[currentHighestBidId].amount) {
            currentHighestBidId = numberOfBids;
        }

        emit BidPlaced(
            msg.sender,
            msg.value,
            numberOfBids,
            nextAvailableIpfsIndex
        );

        numberOfBids++;
        numberOfActiveBids++;
    }

    function sendFundsToEtherFiNode(uint256 _validatorId, uint256 _stakeId)
        external
        onlyStakingManagerContract
    {
        StakingManager depositContractInstance = StakingManager(stakingManagerContractAddress);
        (
            ,
            address withdrawalSafe,
            ,
            ,
            uint256 winningBidId,
            ,

        ) = depositContractInstance.stakes(_stakeId);

        uint256 amount = bids[winningBidId].amount;

        safeInstance = IEtherFiNode(withdrawalSafe);
        IEtherFiNodesManager managerInstance = IEtherFiNodesManager(
            withdrawSafeManager
        );
        managerInstance.receiveAuctionFunds(_validatorId, amount);

        (bool sent, ) = payable(withdrawalSafe).call{value: amount}("");
        require(sent, "Failed to send Ether");

        emit FundsSentToEtherFiNode(amount);
    }

    /// @notice Lets a bid that was matched to a cancelled stake re-enter the auction
    /// @param _bidId the ID of the bid which was matched to the cancelled stake.
    function reEnterAuction(uint256 _bidId)
        external
        onlyStakingManagerContract
        whenNotPaused
    {
        require(bids[_bidId].isActive == false, "Bid already active");

        //Reactivate the bid
        bids[_bidId].isActive = true;

        //Checks if the bid is now the highest bid
        if (bids[_bidId].amount > bids[currentHighestBidId].amount) {
            currentHighestBidId = _bidId;
        }

        numberOfActiveBids++;

        emit BidReEnteredAuction(_bidId);
    }

    /// @notice Updates the merkle root whitelists have been updated
    /// @dev merkleroot gets generated in JS offline and sent to the contract
    /// @param _newMerkle new merkle root to be used for bidding
    function updateMerkleRoot(bytes32 _newMerkle) external onlyOwner {
        bytes32 oldMerkle = merkleRoot;
        merkleRoot = _newMerkle;

        emit MerkleUpdated(oldMerkle, _newMerkle);
    }

    /// @notice Sets the depositContract address in the current contract
    /// @dev Called by depositContract and can only be called once
    /// @param _stakingManagerContractAddress address of the depositContract for authorizations
    function setStakingManagerContractAddress(address _stakingManagerContractAddress)
        external
        onlyOwner
    {
        stakingManagerContractAddress = _stakingManagerContractAddress;

        emit StakingManagerAddressSet(_stakingManagerContractAddress);
    }

    /// @notice Updates the minimum bid price
    /// @param _newMinBidAmount the new amount to set the minimum bid price as
    function setMinBidPrice(uint256 _newMinBidAmount) external onlyOwner {
        require(_newMinBidAmount < MAX_BID_AMOUNT, "Min bid exceeds max bid");
        uint256 oldMinBidAmount = minBidAmount;
        minBidAmount = _newMinBidAmount;

        emit MinBidUpdated(oldMinBidAmount, _newMinBidAmount);
    }

    function updateWhitelistMinBidAmount(uint256 _newAmount)
        external
        onlyOwner
    {
        require(_newAmount < minBidAmount && _newAmount > 0, "Invalid Amount");
        uint256 oldBidAmount = whitelistBidAmount;
        whitelistBidAmount = _newAmount;

        emit WhitelistBidUpdated(oldBidAmount, _newAmount);
    }

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    //Allows ether to be sent to this contract
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  GETTER   --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Fetches how many active bids there are and sends it to the caller
    /// @dev Needed for deposit to check if there are any active bids
    /// @return numberOfActiveBids the number of current active bids
    function getNumberOfActivebids() external view returns (uint256) {
        return numberOfActiveBids;
    }

    function getBidOwner(uint256 _bidId) external view returns (address) {
        return bids[_bidId].bidderAddress;
    }

    function setManagerAddress(address _managerAddress) external {
        withdrawSafeManager = _managerAddress;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContractAddress,
            "Only deposit contract function"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
