// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//Importing all needed contracts and libraries
import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/ITreasury.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./Deposit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Auction is IAuction, Pausable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public currentHighestBidId;
    uint256 public whitelistBidAmount = 0.001 ether;
    uint256 public minBidAmount = 0.01 ether;
    uint256 public constant MAX_BID_AMOUNT = 5 ether;
    uint256 public numberOfBids = 1;
    uint256 public numberOfActiveBids;
    address public depositContractAddress;
    address public treasuryContractAddress;
    address public owner;
    bytes32 public merkleRoot;

    mapping(uint256 => Bid) public bids;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event BidPlaced(
        address indexed bidder,
        uint256 amount,
        uint256 indexed bidId,
        bytes bidderPublicKey
    );

    event WinningBidSent(address indexed winner, uint256 indexed highestBidId);
    event BidReEnteredAuction(uint256 indexed bidId);
    event BiddingEnabled();
    event BidCancelled(uint256 indexed bidId);
    event BidUpdated(uint256 indexed bidId, uint256 valueUpdatedBy);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);
    event DepositAddressSet(address indexed depositContractAddress);
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
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    /// @param _treasuryAddress the address of the treasury to send funds to
    constructor(address _treasuryAddress) {
        treasuryContractAddress = _treasuryAddress;
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice calculates the winning operator bid when a stake is deposited
    /// @dev Used local variables to prevent multiple calling of state variables to save gas
    /// @dev Gets called from the deposit contract when a stake is received
    /// @param _withdrawSafe address of the withdraw safe to send funds to
    /// @return winningOperator the address of the current highest bidder
    function calculateWinningBid(address _withdrawSafe)
        external
        onlyDepositContract
        returns (uint256)
    {
        uint256 currentHighestBidIdLocal = currentHighestBidId;
        uint256 numberOfBidsLocal = numberOfBids;

        //Set the bid to be de-activated to prevent 1 bid winning twice
        bids[currentHighestBidIdLocal].isActive = false;

        address winningOperator = bids[currentHighestBidIdLocal].bidderAddress;

        uint256 winningBidAmount = bids[currentHighestBidIdLocal].amount;

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

        //Send the winning bid to the treasury contract
        (bool sent, ) = treasuryContractAddress.call{value: winningBidAmount}(
            ""
        );
        require(sent, "Failed to send Ether");

        numberOfActiveBids--;

        emit WinningBidSent(winningOperator, currentHighestBidIdLocal);
        return currentHighestBidIdLocal;
    }

    /// @notice Increases a currently active bid by a specified amount
    /// @dev First require checks both if the bid doesnt exist and if its called by incorrect owner
    /// @param _bidId the ID of the bid to increase
    function increaseBid(uint256 _bidId) external payable whenNotPaused {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");
        require(
            msg.value + bids[_bidId].amount <= MAX_BID_AMOUNT,
            "Above max bid"
        );

        bids[_bidId].amount += msg.value;

        //Checks if the updated amount is now the current highest bid
        if (bids[_bidId].amount > bids[currentHighestBidId].amount) {
            currentHighestBidId = _bidId;
        }

        emit BidUpdated(_bidId, msg.value);
    }

    /// @notice decreases a currently active bid by a specified amount
    /// @dev First require checks both if the bid doesnt exist and if its called by incorrect owner
    /// @param _bidId the ID of the bid to decrease
    /// @param _amount the amount to decrease the bid by
    function decreaseBid(uint256 _bidId, uint256 _amount)
        external
        whenNotPaused
    {
        require(bids[_bidId].isActive == true, "Bid already cancelled");
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].amount > _amount, "Amount too large");
        require(
            bids[_bidId].amount - _amount >= minBidAmount,
            "Bid Below Min Bid"
        );

        //Set local variable for read operations to save gas
        uint256 numberOfBidsLocal = numberOfBids;
        bids[_bidId].amount -= _amount;

        //Checks if the updated bid was the current highest bid
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

        //Refund the user with their decreased amount
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        emit BidUpdated(_bidId, _amount);
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
    function bidOnStake(
        bytes32[] calldata _merkleProof,
        bytes memory _bidderPublicKey
    ) external payable whenNotPaused {
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

        //Creates a bid object for storage and lookup in future
        bids[numberOfBids] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender,
            isActive: true,
            bidderPublicKey: _bidderPublicKey
        });

        //Checks if the bid is now the highest bid
        if (msg.value > bids[currentHighestBidId].amount) {
            currentHighestBidId = numberOfBids;
        }

        emit BidPlaced(msg.sender, msg.value, numberOfBids, _bidderPublicKey);

        numberOfBids++;
        numberOfActiveBids++;
    }

    /// @notice Lets a bid that was matched to a cancelled stake re-enter the auction
    /// @param _bidId the ID of the bid which was matched to the cancelled stake.
    /// @param _withdrawSafe the address of the withdraw safe to fetch the funds from
    function reEnterAuction(uint256 _bidId, address _withdrawSafe)
        external
        onlyDepositContract
        whenNotPaused
    {
        require(bids[_bidId].isActive == false, "Bid already active");

        //Reactivate the bid
        bids[_bidId].isActive = true;
        ITreasury(treasuryContractAddress).refundBid(
            bids[_bidId].amount,
            _bidId
        );

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
    /// @param _depositContractAddress address of the depositContract for authorizations
    function setDepositContractAddress(address _depositContractAddress)
        external
        onlyOwner
    {
        depositContractAddress = _depositContractAddress;

        emit DepositAddressSet(_depositContractAddress);
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

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContractAddress,
            "Only deposit contract function"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}