// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//Importing all needed contracts and libraries
import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IAuction.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./Deposit.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Auction is IAuction {

//--------------------------------------------------------------------------------------
//---------------------------------  STATE-VARIABLES  ----------------------------------
//--------------------------------------------------------------------------------------
    
    uint256 public currentHighestBidId;
    uint256 public numberOfBids = 1;
    uint256 public numberOfActiveBids;
    address public depositContractAddress;
    address public treasuryContractAddress;
    bytes32 public merkleRoot;
    bool public bidsEnabled;
    bool public depositContractAddressSet;

    mapping(uint256 => Bid) public bids;

//--------------------------------------------------------------------------------------
//-------------------------------------  EVENTS  ---------------------------------------
//--------------------------------------------------------------------------------------
    
    event BidPlaced(address bidder, uint256 amount, uint256 bidderId);
    event BiddingDisabled(address winner);
    event BiddingEnabled();
    event BidCancelled(uint256 bidId);
    event BidUpdated(uint256 bidId, uint256 valueUpdatedBy);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 newMerkle);

//--------------------------------------------------------------------------------------
//----------------------------------  CONSTRUCTOR   ------------------------------------
//--------------------------------------------------------------------------------------
    
    /// @notice Constructor to set variables on deployment
    /// @param _treasuryAddress the address of the treasury to send funds to
    /// @param _merkleRoot the merkle root which holds the whitelisted addresses for bidding
    constructor(address _treasuryAddress, bytes32 _merkleRoot) {
        bidsEnabled = true;
        treasuryContractAddress = _treasuryAddress;
        merkleRoot = _merkleRoot;
    }

//--------------------------------------------------------------------------------------
//----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
//--------------------------------------------------------------------------------------
    
    /// @notice Disables the bidding to prevent race-conditions on arrival of a stake
    /// @dev Used local variables to prevent multiple calling of state variables to save gas
    /// @dev Gets called from the deposit contract when a stake is received
    /// @return winningOperator the address of the current highest bidder
    function disableBidding() external onlyDepositContract returns (address) {
        uint256 currentHighestBidIdLocal = currentHighestBidId;
        uint256 numberOfBidsLocal = numberOfBids;
        
        //Disable bids to prevent race-conditions
        bidsEnabled = false;

        //Set the bid to be de-activated to prevent 1 bid winning twice
        bids[currentHighestBidIdLocal].isActive = false;
        address winningOperator = bids[currentHighestBidIdLocal].bidderAddress;
        uint256 winningBidAmount = bids[currentHighestBidIdLocal].amount;
        uint256 tempWinningBidId;

        //Loop to calculate the next highest bid for the next stake
        for (uint256 x; x <= numberOfBidsLocal - 1; ++x) {
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

        emit BiddingDisabled(winningOperator);
        return winningOperator;
    }

    /// @notice Enables the bidding
    /// @dev Currently must get called manually for POC
    /// @dev Will be called from deposit contract when validator key is sent
    function enableBidding() external onlyDepositContract {
        require(bidsEnabled == false, "Bids already enabled");
        bidsEnabled = true;
        emit BiddingEnabled();
    }

    /// @notice Increases a currently active bid by a specified amount
    /// @param _bidId the ID of the bid to increase
    function updateBid(uint256 _bidId) external payable {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        bids[_bidId].amount += msg.value;

        //Checks if the updated amount is now the current highest bid
        if (bids[_bidId].amount > bids[currentHighestBidId].amount) {
            currentHighestBidId = _bidId;
        }

        emit BidUpdated(_bidId, msg.value);
    }

    /// @notice Cancels a specified bid by de-activating it
    /// @dev Used local variables to save on multiple state variable lookups
    /// @dev First require checks both if the bid doesnt exist and if its called by incorrect owner
    /// @param _bidId the ID of the bid to cancel
    function cancelBid(uint256 _bidId) external {
        require(bids[_bidId].bidderAddress == msg.sender, "Invalid bid");
        require(bids[_bidId].isActive == true, "Bid already cancelled");

        //Set local variable for read operations to save gas
        uint256 numberOfBidsLocal = numberOfBids;

        //Cancel the bid by de-activating it
        bids[_bidId].isActive = false;

        //Check if the bid being cancelled is the current highest to make sure we
        //calculate a new highest
        if (currentHighestBidId == _bidId) {
            uint256 tempWinningBidId;

            //Calculate the new highest bid
            for (uint256 x; x <= numberOfBidsLocal - 1; ++x) {
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
    function bidOnStake(bytes32[] calldata _merkleProof) external payable {
        require(bidsEnabled == true, "Bidding is on hold");
        require(
            MerkleProof.verify(
                _merkleProof,
                merkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Invalid merkle proof"
        );

        //Creates a bid object for storage and lookup in future
        bids[numberOfBids] = Bid({
            amount: msg.value,
            timeOfBid: block.timestamp,
            bidderAddress: msg.sender,
            isActive: true
        });

        //Checks if the bid is now the highest bid
        if (msg.value > bids[currentHighestBidId].amount) {
            currentHighestBidId = numberOfBids;
        }

        numberOfBids++;
        numberOfActiveBids++;

        emit BidPlaced(msg.sender, msg.value, numberOfBids - 1);
    }

    /// @notice Updates the merkle root whitelists have been updated
    /// @dev erkleroot gets generated in JS offline and sent to the contract
    /// @param _newMerkle new merkle root to be used for bidding
    function updateMerkleRoot(bytes32 _newMerkle) external {
        bytes32 oldMerkle = merkleRoot;
        merkleRoot = _newMerkle;

        emit MerkleUpdated(oldMerkle, _newMerkle);
    }

    /// @notice Sets the depositContract address in the current contract
    /// @dev Called by depositContract and can only be called once
    /// @param _depositContractAddress address of the depositContract for authorizations
    function setDepositContractAddress(address _depositContractAddress)
        external
    {
        require(depositContractAddressSet == false, "Function already called");
        depositContractAddress = _depositContractAddress;
        
        //Setting boolean to true to stop it from being called again
        depositContractAddressSet = true;
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
}
