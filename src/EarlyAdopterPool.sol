// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "lib/forge-std/src/console.sol";

contract EarlyAdopterPool is Ownable {
    using Math for uint256;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public constant depositStandard = 100000000;
    uint256 public constant SCALE = 10e10;
    uint256 public immutable minDeposit = 0.1 ether;
    uint256 public maxDeposit = 100 ether;
    
    // Number of months after which points double in seconds
    uint256 public duration;
    //How much the multiplier must increase per day, actually 0.1 but scaled by 100
    uint256 private multiplierCoefficient = 10;
    uint256 public claimDeadline;
    uint256 public endTime;
    
    address private rETH; // 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private wstETH; // 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private sfrxEth; // 0xac3e018457b222d93114458476f3e3416abbe38f;
    address public claimReceiverContract;

    bool public claimingStatus;

    mapping(address => uint256) public depositTimes;

    mapping(address => mapping(address => uint256)) public userToErc20Balance;
    mapping(address => uint256) public userToETHBalance;

    mapping(address => uint256) public totalUserErc20Balance;

    IERC20 rETHInstance;
    IERC20 wstETHInstance;
    IERC20 sfrxEthInstance;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event DepositERC20(address indexed sender, uint256 amount);
    event DepositEth(address indexed sender, uint256 amount);
    event Withdrawn(
        address indexed sender,
        uint256 amount
    );
    event ClaimReceiverContractSet(address indexed receiverAddress);
    event ClaimingOpened(uint256 deadline);
    event Fundsclaimed(address indexed user, uint256 indexed amount, uint256 indexed pointsAccumulated);


    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(
        address _rETH,
        address _wstEth,
        address _sfrxEth
    ) {
        rETH = _rETH;
        wstETH = _wstEth;
        sfrxEth = _sfrxEth;

        rETHInstance = IERC20(_rETH);
        wstETHInstance = IERC20(_wstEth);
        sfrxEthInstance = IERC20(_sfrxEth);

        claimingStatus = false;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposit into pool
    function deposit(address _ethContract, uint256 _amount) external {
        require((_ethContract == rETH || _ethContract == sfrxEth || _ethContract == wstETH), "Unsupported token");
        require(
            _amount >= minDeposit && _amount <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        
        depositTimes[msg.sender] = block.timestamp;

        userToErc20Balance[msg.sender][_ethContract] += _amount;
        totalUserErc20Balance[msg.sender] += _amount;
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
        userToETHBalance[msg.sender] += msg.value;

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
            
        emit ClaimingOpened(claimDeadline);
       
    }

    function setClaimReceiverContract(address _receiverContract) public onlyOwner {
        require(_receiverContract != address(0), "Cannot set as address zero");
        claimReceiverContract = _receiverContract;

        emit ClaimReceiverContractSet(_receiverContract);
    }

    function calculateUserPoints() public view returns (uint256) {

        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender]; 
        uint256 numberOfMultiplierMilestones;

        if((lengthOfDeposit / 259200) > 2) {
            numberOfMultiplierMilestones = 2;
        }else {
            numberOfMultiplierMilestones = lengthOfDeposit / 259200;
        }

        uint256 userMultiplier = numberOfMultiplierMilestones * multiplierCoefficient;
        uint256 totalUserBalance = userToETHBalance[msg.sender] + totalUserErc20Balance[msg.sender];

        return (((Math.sqrt(totalUserBalance) * lengthOfDeposit) / SCALE) * userMultiplier) / 100;
    }


    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------
    
    function transferFunds(address _user, uint256 _identifier) internal returns (uint256){
        
        uint256 totalUserBalance = msg.sender.balance + totalUserErc20Balance[msg.sender];
        
        uint256 rETHbal = userToErc20Balance[_user][rETH];
        uint256 wstETHbal = userToErc20Balance[_user][wstETH];
        uint256 sfrxEthbal = userToErc20Balance[_user][sfrxEth];
        uint256 ethBalance = userToETHBalance[_user];

        depositTimes[_user] = 0;
        totalUserErc20Balance[msg.sender] = 0;
        userToETHBalance[msg.sender] = 0;
        userToErc20Balance[_user][rETH] = 0;
        userToErc20Balance[_user][wstETH] = 0;
        userToErc20Balance[_user][sfrxEth] = 0;

        address receiver;

        if(_identifier == 0){
            receiver = _user;
        } else {
            receiver = claimReceiverContract;
        }

        rETHInstance.transfer(receiver, rETHbal);
        wstETHInstance.transfer(receiver, wstETHbal);
        sfrxEthInstance.transfer(receiver, sfrxEthbal);

        (bool sent, ) = receiver.call{value: ethBalance}("");
        require(sent, "Failed to send Ether");

        return totalUserBalance;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}
   
}
