// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//Importing all needed contracts and libraries
import "./interfaces/IAuctionManager.sol";
import "./interfaces/INodeOperatorManager.sol";
import "./interfaces/IProtocolRevenueManager.sol";

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/forge-std/src/console.sol";

contract AuctionManager is IAuctionManager, Pausable, Ownable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public whitelistBidAmount = 0.001 ether;
    uint256 public minBidAmount = 0.01 ether;
    uint256 public maxBidAmount = 5 ether;
    uint256 public numberOfBids = 1;
    uint256 public numberOfActiveBids;

    address public stakingManagerContractAddress;
    address public nodeOperatorManagerContractAddress;
    bool public whitelistEnabled = true;

    mapping(uint256 => Bid) public bids;

    INodeOperatorManager nodeOperatorManagerInterface;
    IProtocolRevenueManager protocolRevenueManager;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event BidCreated(
        address indexed bidder,
        uint256 amountPerBid,
        uint256[] bidIdArray,
        uint64[] ipfsIndexArray
    );
    event BidCancelled(uint256 indexed bidId);
    event BidReEnteredAuction(uint256 indexed bidId);
    event Received(address indexed sender, uint256 value);

    //--------------------------------------------------------------------------------------
    //------------------------------------  RECEIVER   -------------------------------------
    //--------------------------------------------------------------------------------------

    // Allows ether to be sent to this contract
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    constructor(address _nodeOperatorManagerContract) {
        nodeOperatorManagerInterface = INodeOperatorManager(
            _nodeOperatorManagerContract
        );
        nodeOperatorManagerContractAddress = _nodeOperatorManagerContract;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Creates bid(s) for the right to run a validator node when ETH is deposited
    /// @param _bidSize the number of bids that the node operator would like to create
    /// @param _bidAmountPerBid the ether value of each bid that is created
    /// @return bidIdArray array of the bidIDs that were created
    function createBid(uint256 _bidSize, uint256 _bidAmountPerBid)
        external
        payable
        whenNotPaused
        returns (uint256[] memory) 
    {
        if (whitelistEnabled) {
            require(
                nodeOperatorManagerInterface.isWhitelisted(msg.sender) == true,
                "Only whitelisted addresses"
            );
            require(
                msg.value == _bidSize * _bidAmountPerBid &&
                    _bidAmountPerBid >= whitelistBidAmount &&
                    _bidAmountPerBid <= maxBidAmount,
                "Incorrect bid value"
            );
        } else {
            if (nodeOperatorManagerInterface.isWhitelisted(msg.sender) == true) {
                require(
                    msg.value == _bidSize * _bidAmountPerBid &&
                        _bidAmountPerBid >= whitelistBidAmount &&
                        _bidAmountPerBid <= maxBidAmount,
                    "Incorrect bid value"
                );
            } else {
                require(
                    msg.value == _bidSize * _bidAmountPerBid &&
                        _bidAmountPerBid >= minBidAmount &&
                        _bidAmountPerBid <= maxBidAmount,
                    "Incorrect bid value"
                );
            }
        }

        uint64 keysRemaining = nodeOperatorManagerInterface.getNumKeysRemaining(msg.sender);
        require(_bidSize <= keysRemaining, "Insufficient public keys");

        uint256[] memory bidIdArray = new uint256[](_bidSize);
        uint64[] memory ipfsIndexArray = new uint64[](_bidSize);

        for (uint256 i = 0; i < _bidSize; i = uncheckedInc(i)) {
            uint64 ipfsIndex = nodeOperatorManagerInterface
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
        emit BidCreated(msg.sender, _bidAmountPerBid, bidIdArray, ipfsIndexArray);
        return bidIdArray;
    }

    /// @notice Cancels a specified bid by de-activating it
    /// @dev Require the bid to exist and be active
    /// @param _bidId the ID of the bid to cancel
    function cancelBid(uint256 _bidId) external whenNotPaused {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        // Cancel the bid by de-activating it
        bids[_bidId].isActive = false;

        // Get the value of the cancelled bid to refund
        uint256 bidValue = bids[_bidId].amount;

        // Refund the user with their bid amount
        (bool sent, ) = msg.sender.call{value: bidValue}("");
        require(sent, "Failed to send Ether");

        numberOfActiveBids--;

        emit BidCancelled(_bidId);
    }

    /// @notice Updates a bid winning bids details
    /// @dev Called by batchDepositWithBidIds() in StakingManager.sol
    /// @param _bidId the ID of the bid being removed from the auction (since it has been selected)
    function updateSelectedBidInformation(uint256 _bidId) public onlyStakingManagerContract {
        require(bids[_bidId].isActive, "The bid is not active");

        bids[_bidId].isActive = false;
        address operator = bids[_bidId].bidderAddress;

        numberOfActiveBids--;
    }
    
    /// @notice Lets a bid that was matched to a cancelled stake re-enter the auction
    /// @param _bidId the ID of the bid which was matched to the cancelled stake.
    function reEnterAuction(uint256 _bidId) external onlyStakingManagerContract whenNotPaused {
        require(bids[_bidId].isActive == false, "Bid already active");
        //Reactivate the bid
        bids[_bidId].isActive = true;
        numberOfActiveBids++;
        emit BidReEnteredAuction(_bidId);
    }

    /// @notice Transfer the auction fee received from the node operator to the protocol revenue manager
    /// @dev Called by registerValidator() in StakingManager.sol
    /// @param _bidId the ID of the validator
    function processAuctionFeeTransfer(uint256 _bidId) external onlyStakingManagerContract {
        uint256 amount = bids[_bidId].amount;
        protocolRevenueManager.addAuctionRevenue{value: amount}(_bidId);
    }

    /// @notice Disables the bid whitelist
    /// @dev Allows both regular users and whitelisted users to bid
    function disableWhitelist() public onlyOwner {
        whitelistEnabled = false;
    }

    /// @notice Enables the bid whitelist
    /// @dev Only users who are on a whitelist can bid
    function enableWhitelist() public onlyOwner {
        whitelistEnabled = true;
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

    function uncheckedInc(uint256 x) private pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Fetches the address of the user who placed a bid for a specific bid ID
    /// @dev Needed for registerValidator() function in Staking Contract
    /// @return the user who placed the bid
    function getBidOwner(uint256 _bidId) external view returns (address) {
        return bids[_bidId].bidderAddress;
    }

    /// @notice Fetches if a selected bid is currently active
    /// @dev Needed for batchDepositWithBidIds() function in Staking Contract
    /// @return the boolean value of the active flag in bids
    function isBidActive(uint256 _bidId) external view returns (bool) {
        return bids[_bidId].isActive;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets an instance of the protocol revenue manager
    /// @dev Needed to process an auction fee
    /// @param _protocolRevenueManager the addres of the protocol manager
    /// @notice Performed this way due to circular dependencies
    function setProtocolRevenueManager(address _protocolRevenueManager) external onlyOwner {
        protocolRevenueManager = IProtocolRevenueManager(_protocolRevenueManager);
    }

    /// @notice Sets the stakingManagerContractAddress address in the current contract
    /// @param _stakingManagerContractAddress new stakingManagerContract address
    function setStakingManagerContractAddress(address _stakingManagerContractAddress) external onlyOwner {
        stakingManagerContractAddress = _stakingManagerContractAddress;
    }

    /// @notice Updates the minimum bid price
    /// @param _newMinBidAmount the new amount to set the minimum bid price as
    function setMinBidPrice(uint256 _newMinBidAmount) external onlyOwner {
        require(_newMinBidAmount < maxBidAmount, "Min bid exceeds max bid");
        minBidAmount = _newMinBidAmount;
    }

    /// @notice Updates the maximum bid price
    /// @param _newMaxBidAmount the new amount to set the maximum bid price as
    function setMaxBidPrice(uint256 _newMaxBidAmount) external onlyOwner {
        require(_newMaxBidAmount > minBidAmount, "Min bid exceeds max bid");
        maxBidAmount = _newMaxBidAmount;
    }

    /// @notice Updates the minimum bid price for a whitelisted address
    /// @param _newAmount the new amount to set the minimum bid price as
    function updateWhitelistMinBidAmount(uint256 _newAmount) external onlyOwner {
        require(_newAmount < minBidAmount && _newAmount > 0, "Invalid Amount");
        whitelistBidAmount = _newAmount;
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

    modifier onlyNodeOperatorManagerContract() {
        require(
            msg.sender == nodeOperatorManagerContractAddress,
            "Only node operator key manager contract function"
        );
        _;
    }
}
