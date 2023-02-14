// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/ITNFT.sol";
import "./interfaces/IBNFT.sol";
import "./interfaces/IAuction.sol";
import "./interfaces/IDeposit.sol";
import "./interfaces/IDepositContract.sol";
import "./interfaces/IWithdrawSafe.sol";
import "./TNFT.sol";
import "./BNFT.sol";
import "./WithdrawSafe.sol";
import "./WithdrawSafeManager.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Deposit is IDeposit, Pausable {
    TNFT public TNFTInstance;
    BNFT public BNFTInstance;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuction public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;

    uint256 public stakeAmount;
    uint256 public numberOfStakes = 0;
    uint256 public numberOfValidators = 0;
    address public owner;
    address private managerAddress;

    mapping(address => uint256) public depositorBalances;
    mapping(uint256 => Validator) public validators;
    mapping(uint256 => Stake) public stakes;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event StakeDeposit(
        address indexed sender,
        uint256 value,
        uint256 id,
        uint256 winningBidId
    );
    event StakeCancelled(uint256 id);
    event ValidatorRegistered(
        uint256 bidId,
        uint256 stakeId,
        uint256 validatorId
    );
    event ValidatorAccepted(uint256 validatorId);

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
        depositContractEth2 = IDepositContract(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b
        );
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Allows a user to stake their ETH
    /// @dev This is phase 1 of the staking process, validation key submition is phase 2
    /// @dev Function disables bidding until it is manually enabled again or validation key is submitted
    function deposit() public payable whenNotPaused {
        uint256 localNumOfStakes = numberOfStakes;
        
        require(msg.value == stakeAmount, "Insufficient staking amount");
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >= 1,
            "No bids available at the moment"
        );

        WithdrawSafe withdrawSafeInstance = new WithdrawSafe();

        //Create a stake object and store it in a mapping
        stakes[localNumOfStakes] = Stake({
            staker: msg.sender,
            withdrawSafe: address(withdrawSafeInstance),
            deposit_data: DepositData(address(0), "", "", "", ""),
            amount: msg.value,
            winningBidId: auctionInterfaceInstance.calculateWinningBid(),
            stakeId: localNumOfStakes,
            phase: STAKE_PHASE.DEPOSITED
        });

        depositorBalances[msg.sender] += msg.value;

        emit StakeDeposit(
            msg.sender,
            msg.value,
            localNumOfStakes,
            stakes[numberOfStakes].winningBidId
        );

        numberOfStakes++;
    }

    /// @notice Creates validator object and updates information
    /// @dev Still looking at solutions to storing key on-chain
    /// @param _stakeId id of the stake the validator connects to
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function registerValidator(
        uint256 _stakeId,
        DepositData calldata _depositData
    ) public whenNotPaused {
        require(msg.sender == stakes[_stakeId].staker, "Incorrect caller");
        require(
            stakes[_stakeId].phase == STAKE_PHASE.DEPOSITED,
            "Stake not in correct phase"
        );

        validators[numberOfValidators] = Validator({
            validatorId: numberOfValidators,
            bidId: stakes[_stakeId].winningBidId,
            stakeId: _stakeId,
            phase: VALIDATOR_PHASE.HANDOVER_READY
        });

        stakes[_stakeId].deposit_data = _depositData;
        stakes[_stakeId].phase = STAKE_PHASE.VALIDATOR_REGISTERED;
        numberOfValidators++;

        emit ValidatorRegistered(
            stakes[_stakeId].winningBidId,
            _stakeId,
            numberOfValidators - 1
        );
    }

    /// @notice node operator accepts validator key and data which allows the stake to be deposited into the beacon chain
    /// @dev future iterations will account for if the operator doesnt accept the validator
    /// @param _validatorId id of the validator to be accepted
    function acceptValidator(uint256 _validatorId) public whenNotPaused {
        require(
            msg.sender ==
                auctionInterfaceInstance.getBidOwner(
                    validators[_validatorId].bidId
                ),
            "Incorrect caller"
        );
        require(
            validators[_validatorId].phase == VALIDATOR_PHASE.HANDOVER_READY,
            "Validator not in correct phase"
        );

        uint256 localStakeId = validators[_validatorId].stakeId;

        TNFTInterfaceInstance.mint(stakes[localStakeId].staker, _validatorId);
        BNFTInterfaceInstance.mint(stakes[localStakeId].staker, _validatorId);
        
        WithdrawSafeManager manager = WithdrawSafeManager(managerAddress);
        manager.setOperatorAddress(_validatorId, msg.sender);
        manager.setWithdrawSafeAddress(_validatorId, stakes[localStakeId].withdrawSafe);

        validators[_validatorId].phase = VALIDATOR_PHASE.ACCEPTED;

        auctionInterfaceInstance.sendFundsToWithdrawSafe(_validatorId, localStakeId);

        DepositData memory dataInstance = stakes[localStakeId].deposit_data;

        // depositContractEth2.deposit{value: stakeAmount}(
        //     dataInstance.publicKey,
        //     abi.encodePacked(dataInstance.withdrawalCredentials),
        //     dataInstance.signature,
        //     dataInstance.depositDataRoot
        // );

        emit ValidatorAccepted(_validatorId);
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _stakeId the ID of the stake to cancel
    function cancelStake(uint256 _stakeId) public whenNotPaused {
        require(msg.sender == stakes[_stakeId].staker, "Not bid owner");
        require(
            stakes[_stakeId].phase == STAKE_PHASE.DEPOSITED,
            "Cancelling availability closed"
        );

        uint256 stakeAmountTemp = stakes[_stakeId].amount;
        depositorBalances[msg.sender] -= stakeAmountTemp;

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(stakes[_stakeId].winningBidId);

        stakes[_stakeId].phase = STAKE_PHASE.INACTIVE;
        stakes[_stakeId].winningBidId = 0;

        refundDeposit(msg.sender, stakeAmountTemp);

        emit StakeCancelled(_stakeId);
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

    /// @notice Allows withdrawal of funds from contract
    /// @dev Will be removed in final version
    /// @param _wallet the address to send the funds to
    function fetchEtherFromContract(address _wallet) public onlyOwner {
        (bool sent, ) = payable(_wallet).call{value: address(this).balance}("");
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

    // Gets the addresses of the deployed NFT contracts
    function getNFTAdresses() public view returns (address, address) {
        return (address(TNFTInstance), address(BNFTInstance));
    }

    function getStakerRelatedToValidator(uint256 _validatorId) external returns(address){
        return stakes[validators[_validatorId].stakeId].staker;
    }

    function getStakeAmount() external returns(uint256){
        return stakeAmount;
    }

    function setManagerAddress(address _managerAddress) external {
        managerAddress = _managerAddress;
    }


    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
