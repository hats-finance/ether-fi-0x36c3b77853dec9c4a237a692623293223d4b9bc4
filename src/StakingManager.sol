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

    /// @dev please remove before mainnet deployment
    bool public test = true;

    TNFT public TNFTInstance;
    BNFT public BNFTInstance;

    ITNFT public TNFTInterfaceInstance;
    IBNFT public BNFTInterfaceInstance;
    IAuctionManager public auctionInterfaceInstance;
    IDepositContract public depositContractEth2;
    IEtherFiNodesManager public nodesManagerIntefaceInstance;

    uint256 public stakeAmount;

    address public owner;
    address public treasuryAddress;
    address public auctionAddress;
    address public nodesManagerAddress;

    mapping(uint256 => address) public bidIdToStaker;

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
    /// @param _bidId 0 means calculate winning bid from auction, anything above 0 is a bid id the staker has selected
    function deposit(uint256 _bidId) public payable whenNotPaused returns (uint256) {
        require(msg.value == stakeAmount, "Insufficient staking amount");
        require(
            auctionInterfaceInstance.getNumberOfActivebids() >= 1,
            "No bids available at the moment"
        );
        require(bidIdToStaker[_bidId] == address(0), "");
        
        if(_bidId == 0){
            _bidId = auctionInterfaceInstance.fetchWinningBid();
        }else {
            auctionInterfaceInstance.updateSelectedBidInformation(_bidId);
        }

        // Take the bid; Set the matched staker for the bid
        bidIdToStaker[_bidId] = msg.sender;

        // Let validatorId = BidId
        uint256 validatorId = _bidId;

        // Create the node contract
        address etherfiNode = nodesManagerIntefaceInstance.createEtherfiNode(validatorId);
        nodesManagerIntefaceInstance.setEtherFiNodePhase(validatorId, IEtherFiNode.VALIDATOR_PHASE.STAKE_DEPOSITED);

        emit StakeDeposit(
            msg.sender,
            validatorId,
            _bidId,
            etherfiNode
        );

        return validatorId;
    }

    /// @notice Creates validator object, mints NFTs, sets NB variables and deposits into beacon chain
    /// @param _validatorId id of the validator to register
    /// @param _depositData data structure to hold all data needed for depositing to the beacon chain
    function registerValidator(
        uint256 _validatorId,
        DepositData calldata _depositData
    ) public whenNotPaused {
        require(bidIdToStaker[_validatorId] != address(0), "Deposit does not exist");
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");
        address staker = bidIdToStaker[_validatorId];

        // Let valiadatorId = nftTokenId
        // Mint {T, B}-NFTs to the Staker
        uint256 nftTokenId = _validatorId;
        TNFTInterfaceInstance.mint(staker, nftTokenId);
        BNFTInterfaceInstance.mint(staker, nftTokenId);
        
        // TODO - Revisit it later since we will have ProtocolRevenueManager to handle it
        auctionInterfaceInstance.sendFundsToEtherFiNode(_validatorId);

        if (test = false) {
            bytes memory withdrawalCredentials = nodesManagerIntefaceInstance.getWithdrawalCredentials(_validatorId);
            depositContractEth2.deposit{value: stakeAmount}(
                _depositData.publicKey,
                withdrawalCredentials,
                _depositData.signature,
                _depositData.depositDataRoot
            );
        }
        
        nodesManagerIntefaceInstance.setEtherFiNodePhase(_validatorId, IEtherFiNode.VALIDATOR_PHASE.REGISTERED);
        nodesManagerIntefaceInstance.setEtherFiNodeIpfsHashForEncryptedValidatorKey(_validatorId, _depositData.ipfsHashForEncryptedValidatorKey);

        emit ValidatorRegistered(
            _validatorId,
            _validatorId
        );
    }

    /// @notice Cancels a users stake
    /// @dev Only allowed to be cancelled before step 2 of the depositing process
    /// @param _validatorId the ID of the validator deposit to cancel
    function cancelDeposit(uint256 _validatorId) public whenNotPaused {
        require(bidIdToStaker[_validatorId] != address(0), "Deposit does not exist");
        require(bidIdToStaker[_validatorId] == msg.sender, "Not deposit owner");

        //Call function in auction contract to re-initiate the bid that won
        //Send in the bid ID to be re-initiated
        auctionInterfaceInstance.reEnterAuction(_validatorId);

        // Mark Canceled
        nodesManagerIntefaceInstance.setEtherFiNodePhase(_validatorId, IEtherFiNode.VALIDATOR_PHASE.CANCELLED);

        // Unset the pointers
        bidIdToStaker[_validatorId] = address(0);
        nodesManagerIntefaceInstance.uninstallEtherFiNode(_validatorId);

        refundDeposit(msg.sender, stakeAmount);

        emit DepositCancelled(_validatorId);

        require(bidIdToStaker[_validatorId] == address(0), "");
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
        return bidIdToStaker[_validatorId];
    }

    function getStakeAmount() external view returns (uint256) {
        return stakeAmount;
    }

    function setEtherFiNodesManagerAddress(address _nodesManagerAddress) external {
        nodesManagerAddress = _nodesManagerAddress;
        nodesManagerIntefaceInstance = IEtherFiNodesManager(nodesManagerAddress);
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
