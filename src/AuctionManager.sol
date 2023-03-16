// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//Importing all needed contracts and libraries
import "./interfaces/IAuctionManager.sol";
import "./interfaces/INodeOperatorKeyManager.sol";
import "./interfaces/IProtocolRevenueManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/forge-std/src/console.sol";

contract AuctionManager is IAuctionManager, Pausable, Ownable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public whitelistBidAmount = 0.001 ether;
    uint256 public minBidAmount = 0.01 ether;
    uint256 public constant MAX_BID_AMOUNT = 5 ether;
    uint256 public numberOfBids = 1;
    uint256 public numberOfActiveBids;
    uint256 public currentHighestBidId;
    address public stakingManagerContractAddress;
    bytes32 public merkleRoot;
    bool public whitelistEnabled = true;

    mapping(uint256 => Bid) public bids;

    INodeOperatorKeyManager nodeOperatorKeyManagerInterface;
    IProtocolRevenueManager protocolRevenueManager;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event BidCreated(
        address indexed bidder,
        uint256 amount,
        uint256[] indexed bidIdArray,
        uint64[] indexed ipfsIndexArray
    );

    event SelectedBidUpdated(
        address indexed winner,
        uint256 indexed highestBidId
    );
    event BidReEnteredAuction(uint256 indexed bidId);
    event BiddingEnabled();
    event BidCancelled(uint256 indexed bidId);
    event BidUpdated(uint256 indexed bidId, uint256 valueUpdatedBy);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);
    event StakingManagerAddressSet(
        address indexed stakingManagerContractAddress
    );
    event MinBidUpdated(
        uint256 indexed oldMinBidAmount,
        uint256 indexed newMinBidAmount
    );
    event WhitelistBidUpdated(
        uint256 indexed oldBidAmount,
        uint256 indexed newBidAmount
    );
    event Received(address indexed sender, uint256 value);

    //--------------------------------------------------------------------------------------
    //------------------------------------  RECEIVER   -------------------------------------
    //--------------------------------------------------------------------------------------

    //Allows ether to be sent to this contract
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    constructor(address _nodeOperatorKeyManagerContract) {
        nodeOperatorKeyManagerInterface = INodeOperatorKeyManager(
            _nodeOperatorKeyManagerContract
        );
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Updates a winning bids details
    /// @dev Called either by the fetchWinningBid() function or from the staking contract
    /// @param _bidId the ID of the bid being removed from the auction; either due to being selected by a staker or being the current highest bid
    /// TODO add a staker param and set the stakerAddress in the bid struct
    /// TODO add require to check if staker address is address(0)
    function updateSelectedBidInformation(uint256 _bidId) public {
        require(
            msg.sender == stakingManagerContractAddress ||
                msg.sender == address(this),
            "Incorrect Caller"
        );
        require(bids[_bidId].isActive, "The bid is not active");

        bids[_bidId].isActive = false;
        address operator = bids[_bidId].bidderAddress;

        numberOfActiveBids--;

        emit SelectedBidUpdated(operator, _bidId);
    }

    /// @notice Cancels a specified bid by de-activating it
    /// @dev Used local variables to save on multiple state variable lookups
    /// @dev First require checks both if the bid doesnt exist and if its called by incorrect owner
    /// @param _bidId the ID of the bid to cancel
    function cancelBid(uint256 _bidId) external whenNotPaused {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        //Cancel the bid by de-activating it
        bids[_bidId].isActive = false;

        //Get the value of the cancelled bid to refund
        uint256 bidValue = bids[_bidId].amount;

        //Refund the user with their bid amount
        (bool sent, ) = msg.sender.call{value: bidValue}("");
        require(sent, "Failed to send Ether");

        numberOfActiveBids--;

        emit BidCancelled(_bidId);
    }

    /// @notice Creates bids that are able to be place in the auction  or be selected  by a staker
    /// @notice all bid amounts are the same. You cannot create one bid of 1 ETH and another of 2 ETH
    /// @dev Merkleroot gets generated in JS offline and sent to the contract
    /// @param _merkleProof the merkleproof for the user calling the function
    /// @param _bidSize the number of bids that the node operator would like to create
    /// @param _bidAmountPerBid the ether value of 1 bid.
    function createBidWhitelisted(
        bytes32[] calldata _merkleProof,
        uint256 _bidSize,
        uint256 _bidAmountPerBid
    ) external payable whenNotPaused returns (uint256[] memory) {
        uint64 userTotalKeys = nodeOperatorKeyManagerInterface.getUserTotalKeys(
            msg.sender
        );
        
        require(whitelistEnabled, "Whitelist disabled");
        require(_bidSize <= userTotalKeys, "Insufficient public keys");

        // Checks if bidder is on whitelist
        require(
            MerkleProof.verify(
                _merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Only whitelisted addresses"
        );

        require(
            msg.value == _bidSize * _bidAmountPerBid &&
                _bidAmountPerBid >= whitelistBidAmount &&
                _bidAmountPerBid <= MAX_BID_AMOUNT,
            "Incorrect bid value"
        );

        uint256[] memory bidIdArray = new uint256[](_bidSize);
        uint64[] memory ipfsIndexArray = new uint64[](_bidSize);

        for (uint256 i = 0; i < _bidSize; i = uncheckedInc(i)) {
            uint64 ipfsIndex = nodeOperatorKeyManagerInterface
                .fetchNextKeyIndex(msg.sender);

            uint256 bidId = numberOfBids;

            bidIdArray[i] = bidId;
            ipfsIndexArray[i] = ipfsIndex;

            //Creates a bid object for storage and lookup in future
            bids[bidId] = Bid({
                amount: _bidAmountPerBid,
                bidderPubKeyIndex: ipfsIndex,
                bidderAddress: msg.sender,
                isActive: true
            });

            numberOfBids++;
        }

        numberOfActiveBids += _bidSize;
        emit BidCreated(msg.sender, msg.value, bidIdArray, ipfsIndexArray);
        return bidIdArray;
    }

    function createBidPermissionless(
        uint256 _bidSize,
        uint256 _bidAmountPerBid
    ) external payable whenNotPaused returns (uint256[] memory) {
        uint64 userTotalKeys = nodeOperatorKeyManagerInterface.getUserTotalKeys(
            msg.sender
        );

        require(_bidSize <= userTotalKeys, "Insufficient public keys");
        require(!whitelistEnabled, "Whitelist enabled");

        require(
            msg.value == _bidSize * _bidAmountPerBid &&
                _bidAmountPerBid >= minBidAmount &&
                _bidAmountPerBid <= MAX_BID_AMOUNT,
            "Incorrect bid value"
        );

        uint256[] memory bidIdArray = new uint256[](_bidSize);
        uint64[] memory ipfsIndexArray = new uint64[](_bidSize);

        for (uint256 i = 0; i < _bidSize; i = uncheckedInc(i)) {
            uint64 ipfsIndex = nodeOperatorKeyManagerInterface
                .fetchNextKeyIndex(msg.sender);
            uint256 bidId = numberOfBids;

            bidIdArray[i] = bidId;
            ipfsIndexArray[i] = ipfsIndex;

            //Creates a bid object for storage and lookup in future
            bids[bidId] = Bid({
                amount: _bidAmountPerBid,
                bidderPubKeyIndex: ipfsIndex,
                bidderAddress: msg.sender,
                isActive: true
            });

            numberOfBids++;
        }

        numberOfActiveBids += _bidSize;
        emit BidCreated(
            msg.sender,
            uint64(msg.value),
            bidIdArray,
            ipfsIndexArray
        );
        return bidIdArray;
    }

    function disableWhitelist() public onlyOwner {
        whitelistEnabled = false;
    }

    function enableWhitelist() public onlyOwner {
        whitelistEnabled = true;
    }

    /// @notice Transfer the auction fee received from the node operator to the protocol revenue manager
    /// @param _bidId the ID of the validator
    function processAuctionFeeTransfer(
        uint256 _bidId
    ) external onlyStakingManagerContract {
        uint256 amount = bids[_bidId].amount;
        protocolRevenueManager.addAuctionRevenue{value: amount}(_bidId);
    }

    /// @notice Lets a bid that was matched to a cancelled stake re-enter the auction
    /// @param _bidId the ID of the bid which was matched to the cancelled stake.
    function reEnterAuction(
        uint256 _bidId
    ) external onlyStakingManagerContract whenNotPaused {
        require(bids[_bidId].isActive == false, "Bid already active");

        //Reactivate the bid
        bids[_bidId].isActive = true;
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
    function setStakingManagerContractAddress(
        address _stakingManagerContractAddress
    ) external onlyOwner {
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

    /// @notice Updates the minimum bid price for a whitelisted address
    /// @param _newAmount the new amount to set the minimum bid price as
    function updateWhitelistMinBidAmount(
        uint256 _newAmount
    ) external onlyOwner {
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

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function uncheckedInc(uint x) private pure returns (uint) {
        unchecked {
            return x + 1;
        }
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

    /// @notice Fetches the address of the user who placed a bid for a specific bid ID
    /// @dev Needed for registerValidator() function in Staking Contract
    /// @return the user who placed the bid
    function getBidOwner(uint256 _bidId) external view returns (address) {
        return bids[_bidId].bidderAddress;
    }

    function isBidActive(uint256 _bidId) external view returns (bool) {
        return bids[_bidId].isActive;
    }

    function setProtocolRevenueManager(
        address _protocolRevenueManager
    ) external {
        protocolRevenueManager = IProtocolRevenueManager(
            _protocolRevenueManager
        );
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContractAddress,
            "Only staking manager contract function"
        );
        _;
    }
}
