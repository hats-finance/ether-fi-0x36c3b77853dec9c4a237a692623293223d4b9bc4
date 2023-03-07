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
import "@openzeppelin/contracts/security/Pausable.sol";
import "lib/forge-std/src/console.sol";

contract StakingManager is IStakingManager, Pausable {
    TNFT public TNFTInstance;
    BNFT public BNFTInstance;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;

    uint256 public stakeAmount;
    uint256 public numberOfValidators;
    address public owner;
    address private managerAddress;
    address public treasuryAddress;
    address public auctionAddress;
    address public withdrawSafeFactoryAddress;

    /// @dev please remove before mainnet deployment
    bool public test = true;

    mapping(address => uint256) public depositorBalances;
    mapping(uint256 => Validator) public validators;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event NFTContractsDeployed(address TNFTInstance, address BNFTInstance);
    event StakeDeposit(
        address indexed sender,
        uint256 id,
        uint256 winningBidId,
        address withdrawSafe
    );
    event DepositCancelled(uint256 id);
    event ValidatorRegistered(
        uint256 bidId,
        uint256 validatorId
    );
    event ValidatorAccepted(uint256 validatorId);

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
        // stakeAmount = 0.032 ether;
        TNFTInstance = new TNFT();
        BNFTInstance = new BNFT();
        TNFTInterfaceInstance = ITNFT(address(TNFTInstance));
        BNFTInterfaceInstance = IBNFT(address(BNFTInstance));
        auctionInterfaceInstance = IAuctionManager(_auctionAddress);
        depositContractEth2 = IDepositContract(
            0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b
        );
        owner = msg.sender;
        auctionAddress = _auctionAddress;

        emit NFTContractsDeployed(address(TNFTInstance), address(BNFTInstance));
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

    /// @notice Allows a user to stake their ETH
    /// @dev This is phase 1 of the staking process, validation key submition is phase 2
    /// @dev Function disables bidding until it is manually enabled again or validation key is submitted
    function deposit() public payable whenNotPaused {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >= 1,
            "No bids available at the moment"
        );

        IEtherFiNodesManager managerInstance = IEtherFiNodesManager(
            managerAddress
        );

        address withdrawSafe = managerInstance.createWithdrawalSafe();
        uint256 selectedBidId = auctionInterfaceInstance.calculateWinningBid();
        uint256 validatorId = selectedBidId;

        require(validators[validatorId].validatorId == 0, "");

        validators[validatorId] = Validator({
            validatorId: validatorId,
            selectedBidId: selectedBidId,
            staker: msg.sender,
            etherFiNode: withdrawSafe,
            phase: VALIDATOR_PHASE.STAKE_DEPOSITED,
            deposit_data: DepositData(address(0), "", "", "", "")
        });

        depositorBalances[msg.sender] += msg.value;

        emit StakeDeposit(
            msg.sender,
            validatorId,
            selectedBidId,
            withdrawSafe
        );

        numberOfValidators++;
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function registerValidator(
        uint256 _validatorId,
        DepositData calldata _depositData
    ) public whenNotPaused {
        console.log(_validatorId);
        console.log(validators[_validatorId].staker);
        require(msg.sender == validators[_validatorId].staker, "Incorrect caller");
        require(
            validators[_validatorId].phase == VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Validator not in correct phase"
        );
        require(validators[_validatorId].selectedBidId == _validatorId, "bidId must be equal to validatorId");

        validators[_validatorId].deposit_data = _depositData;
        validators[_validatorId].phase = VALIDATOR_PHASE.REGISTERED;

        TNFTInterfaceInstance.mint(validators[_validatorId].staker, _validatorId);
        BNFTInterfaceInstance.mint(validators[_validatorId].staker, _validatorId);

        address etherfiNode = validators[_validatorId].etherFiNode;

        IEtherFiNodesManager managerInstance = IEtherFiNodesManager(
            managerAddress
        );
        
        address operator = auctionInterfaceInstance.getBidOwner(validators[_validatorId].selectedBidId);

        managerInstance.setOperatorAddress(_validatorId, operator);
        managerInstance.setEtherFiNodeAddress(
            _validatorId,
            etherfiNode
        );
        auctionInterfaceInstance.sendFundsToEtherFiNode(
            _validatorId
        );

        DepositData memory dataInstance = validators[_validatorId].deposit_data;

        if (test = false) {
            depositContractEth2.deposit{value: stakeAmount}(
                dataInstance.publicKey,
                abi.encodePacked(dataInstance.withdrawalCredentials),
                dataInstance.signature,
                dataInstance.depositDataRoot
            );
        }
        
        validators[_validatorId].phase = VALIDATOR_PHASE.REGISTERED;

        emit ValidatorRegistered(
            validators[_validatorId].selectedBidId,
            _validatorId
        );
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _validatorId the ID of the validator deposit to cancel
    function cancelDeposit(uint256 _validatorId) public whenNotPaused {
        require(msg.sender == validators[_validatorId].staker, "Not deposit owner");
        require(
            validators[_validatorId].phase == VALIDATOR_PHASE.STAKE_DEPOSITED,
            "Cancelling availability closed"
        );
        require(validators[_validatorId].selectedBidId == _validatorId, "bidId must be equal to validatorId");

        depositorBalances[msg.sender] -= stakeAmount;

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(validators[_validatorId].selectedBidId);

        validators[_validatorId].phase = VALIDATOR_PHASE.CANCELLED;
        validators[_validatorId].selectedBidId = 0;

        refundDeposit(msg.sender, stakeAmount);

        emit DepositCancelled(_validatorId);
    }

    /// @notice Refunds the depositor their staked ether for a specific stake
    /// @dev Gets called internally from cancelStakingManager or when the time runs out for calling registerValidator
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
    // function getNFTAddresses() public view returns (address, address) {
    //     return (address(TNFTInstance), address(BNFTInstance));
    // }

    function getStakerRelatedToValidator(uint256 _validatorId)
        external
        view
        returns (address)
    {
        return validators[_validatorId].staker;
    }

    function getStakeAmount() external view returns (uint256) {
        return stakeAmount;
    }

    function setEtherFiNodesManagerAddress(address _managerAddress) external {
        managerAddress = _managerAddress;
    }

    function setTreasuryAddress(address _treasuryAddress) external {
        treasuryAddress = _treasuryAddress;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
