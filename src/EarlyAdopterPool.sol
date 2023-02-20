// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// import "lib/forge-std/src/console.sol";

contract EarlyAdopterPool is Ownable {
    using Math for uint256;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public constant depositStandard = 100000000;
    uint256 public constant SCALE = 10e12;
    uint256 public immutable minDeposit = 0.1 ether;
    uint256 public maxDeposit = 100 ether;
    uint256 public immutable multiplier = 2;
    
    // Number of months after which points double in seconds
    uint256 public duration;
    //How much the multiplier must increase per 10 days
    uint256 private multiplierCoefficient = 0.4;
    uint256 public claimDeadline;
    uint256 public endTime;
    
    address private rETH; // 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private wstETH; // 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private frxETH; // 0x5E8422345238F34275888049021821E8E08CAa1f;
    address private claimReceiverContract;
    address public owner;

    bool public claimingStatus;

    mapping(address => uint256) public depositTimes;

    mapping(address => mapping(address => uint256)) public userToErc20Balance;
    mapping(address => uint256) public userToETHBalance;

    mapping(address => uint256) public totalUserErc20Balance;

    IERC20 rETHInstance;
    IERC20 wstETHInstance;
    IERC20 frxETHInstance;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event DepositERC20(address indexed sender, uint256 amount);
    event DepositEth(address indexed sender, uint256 amount);
    event Withdrawn(
        address indexed sender,
        uint256 amount,
        uint256 lengthOfDeposit
    );
    event ClaimReceiverContractSet(address receiverAddress);
    event ClaimingStatusSet(bool value);
    event Fundsclaimed(address user, uint256 amount, uint256 pointsAccumulated);


    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(
        address _rETH,
        address _wstEth,
        address _frxETH
    ) {
        rETH = _rETH;
        wstEth = _wstEth;
        frxETH = _frxETH;

        rETHInstance = IERC20(_rETH);
        wstETHInstance = IERC20(_wstEth);
        frxETHInstance = IERC20(_frxETH);

        claimingStatus = false;
        owner = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposit into pool
    function deposit(address _ethContract, uint256 _amount) external {
        require((_ethContract == rETH || _ethContract == frxETH || _ethContract == wstETH), "Unsupported token");
        require(
            _amount >= minDeposit && _amount <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        
        depositTimes[msg.sender] = block.timestamp;

        userToErc20Balance[msg.sender][_ethContract] += (_amount * 10e17);
        totalUserErc20Balance[msg.sender] += (_amount * 10e17);
        IERC20(_ethContract).transferFrom(msg.sender, address(this), _amount);

        emit DepositERC20(msg.sender, _amount);
    }

    /// @notice deposit into pool
    function depositEther() external payable {
        require(
            msg.value >= minDeposit && msg.value <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        
        depositTimes[msg.sender] = block.timestamp;
        userETHBalance[msg.sender] += msg.value;

        emit DepositEth(msg.sender, msg.value);
    }

    /// @notice withdraws all funds from pool for the user calling
    /// @dev no points allocated to users who withdraw
    function withdraw() public payable {

        uint256 balance = transferFunds(msg.sender, 0);

        emit Withdrawn(msg.sender, balance);
    }

    /// @notice Transfers users funds to a new contract such as LP 
    /// @dev can once receiver contract is ready and claiming is open
    function claim() public {
        require(claimingStatus == true, "Claiming not open");
        require(claimReceiverContract != address(0), "Claiming address not set");
        require(block.timestamp <= claimDeadline, "Claiming is complete");

        uint256 pointsRewarded = calculateUserPoints();
        uint256 balance = transferFunds(msg.sender, 1);

        emit Fundsclaimed(msg.sender, balance, pointsRewarded);
    }

    function setClaimingOpen(uint256 _claimDeadline) public onlyOwner {
        claimDeadline = block.timestamp + (_claimDeadline * 86400);
        claimingStatus = true;
        endTime = block.timestamp;
            
        emit ClaimingStatusSet(true, claimDeadline);
       
    }

    function setClaimReceiverContract(address _receiverContract) public onlyOwner {
        require(_receiverContract != address(0), "Cannot set as address zero");
        claimReceiverContract = _receiverContract;

        emit ClaimReceiverContractSet(_receiverContract);
    }

    function calculateUserPoints() public view returns (uint256) {

        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender]; 
        uint256 numberOfMultiplierMilestones = lengthOfDeposit / 864000;
        uint256 multiplier = (numberOfMultiplierMilestones * multiplierCoefficient) + 1;
        uint256 totalUserBalance = msg.sender.balance + totalUserErc20Balance[msg.sender];

        return ((Math.sqrt(userBalance[msg.sender]) * lengthOfDeposit) / SCALE) * multiplier;
    }


    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------
    
    function transferFunds(address _user, uint256 _identifier) internal view returns (uint256){
        
        uint256 balance = userBalance[_user];
        uint256 rETHbal = userTo_rETHBalance[_user];
        uint256 wstETHbal = userTo_wstETHBalance[_user];
        uint256 frxETHbal = userTo_frxETHBalance[_user];

        depositTimes[_user] = 0;
        userBalance[_userr] = 0;
        userTo_rETHBalance[_user] = 0;
        userTo_wstETHBalance[_user] = 0;
        userTo_frxETHBalance[_user] = 0;

        address receiver;

        if(_identifier == 0){
            receiver = _user
        } else {
            receiver = claimReceiverContract;
        }

        rETHInstance.transfer(receiver, rETHbal);
        wstETHInstance.transfer(receiver, wstETHbal);
        frxETHInstance.transfer(receiver, frxETHbal);

        return balance;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  MODIFIERS  -------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
