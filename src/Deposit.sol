// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IDeposit.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Deposit is IDeposit, Pausable {

    TNFT public TNFTInstance;
    BNFT public BNFTInstance;
    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuction public auctionInterfaceInstance;
    uint256 public stakeAmount;
    uint256 public numberOfStakes = 0;
    uint256 public numberOfValidators = 0;
    address public owner;

    mapping(address => uint256) public depositorBalances;
    mapping(address => mapping(uint256 => address)) public stakeToOperator;
    mapping(uint256 => Validator) public validators;
    mapping(uint256 => Stake) public stakes;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------
 
    event StakeDeposit(address indexed sender, uint256 value, uint256 id);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Constructor to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev Auction contract must be deployed first
    /// @param _auctionAddress the address of the auction contract for interaction
    constructor(address _auctionAddress) {
        stakeAmount = 0.032 ether;
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
        TNFTInterfaceInstance = ITNFT(address(TNFTInstance));
        BNFTInterfaceInstance = IBNFT(address(BNFTInstance));
        auctionInterfaceInstance = IAuction(_auctionAddress);
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Allows a user to stake their ETH
    /// @dev This is phase 1 of the staking process, validation key submition is phase 2
    /// @dev Function disables bidding until it is manually enabled again or validation key is submitted
    /// @param _deposit_data This is a bytes hash representative of all deposit requirements
    function deposit(bytes memory _deposit_data) public payable whenNotPaused {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >= 1,
            "No bids available at the moment"
        );

        //Create a stake object and store it in a mapping
        stakes[numberOfStakes] = Stake({
            staker: msg.sender,
            deposit_data: _deposit_data,
            amount: msg.value,
            winningBid: 0,
            stakeId: numberOfStakes,
            phase: STAKE_PHASE.STEP_1
        });
        
        depositorBalances[msg.sender] += msg.value;

        //gets the current highest bid from auction contract
        uint256 winningBidId = auctionInterfaceInstance
            .calculateWinningBid();

        stakes[numberOfStakes].winningBid = winningBidId;

        numberOfStakes++;

        emit StakeDeposit(msg.sender, msg.value, numberOfStakes - 1);
    }

    /// @notice Creates validator object and updates information
    /// @dev Still looking at solutions to storing key on-chain
    /// @param _stakeId id of the stake the validator connects to
    /// @param _validatorKey encrypted validator key which the operator and staker can access 
    function registerValidator(uint256 _stakeId, bytes _validatorKey) public whenNotPaused {
        require(stakes[_stakeId].phase == STAKE_PHASE.STEP_1, "Stake not in correct phase");



    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _stakeId the ID of the stake to cancel
    function cancelStake(uint256 _stakeId) public whenNotPaused {
        require(msg.sender ==  stakes[_stakeId].staker, "Not bid owner");
        require(stakes[_stakeId].phase == STAKE_PHASE.STEP_1, "Cancelling availability closed");

        uint256 stakeAmountTemp = stakes[_stakeId].amount;
        depositorBalances[msg.sender] -= stakeAmountTemp;

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(stakes[_stakeId].winningBid);

        stakes[_stakeId].phase = STAKE_PHASE.INACTIVE;
        stakes[_stakeId].winningBid = 0;

        refundDeposit(msg.sender, stakeAmountTemp);

    }

    /// @notice Refunds the depositor their staked ether for a specific stake
    /// @dev Gets called internally from cancelDeposit or when the time runs out for calling registerValidator
    /// @param _depositOwner address of the user being refunded
    /// @param _amount the amount to refund the depositor
    function refundDeposit(address _depositOwner, uint256 _amount) public {

        //Refund the user with their requested amount
        (bool sent, ) = _depositOwner.call{value: _amount}("");
        require(sent, "Failed to send Ether");
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
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
