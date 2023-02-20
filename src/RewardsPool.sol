// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// import "lib/forge-std/src/console.sol";

contract RewardsPool is Ownable {
    using Math for uint256;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address private rETH; // 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private stETH; // 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private frxETH; // 0x5E8422345238F34275888049021821E8E08CAa1f;

    uint256 public constant depositStandard = 100000000;
    uint256 public constant SCALE = 10e12;

    //How much the multiplier must increase per 10 days
    uint256 private multiplierCoefficient = 0.4;

    // User to time of deposit
    mapping(address => uint256) public depositTimes;

    // user to rETH deposited
    mapping(address => uint256) public userTo_rETHBalance;
    // user to rETH deposited
    mapping(address => uint256) public userTo_stETHBalance;
    // user to frxETH deposited
    mapping(address => uint256) public userTo_frxETHBalance;

    // total user balance
    mapping(address => uint256) public userBalance;

    // User to amount of points
    mapping(address => uint256) public userPoints;

    uint256 public immutable minDeposit = 0.1 ether;
    uint256 public maxDeposit = 100 ether;
    uint256 public immutable multiplier = 2;

    // Number of months after which points double in seconds
    uint256 public duration;

    IERC20 rETHInstance;
    IERC20 stETHInstance;
    IERC20 frxETHInstance;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Withdrawn(
        address indexed sender,
        uint256 amount,
        uint256 lengthOfDeposit
    );
    event DurationSet(uint256 oldDuration, uint256 newDuration);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(
        address _rETH,
        address _stETH,
        address _frxETH
    ) {
        rETH = _rETH;
        stETH = _stETH;
        frxETH = _frxETH;

        rETHInstance = IERC20(_rETH);
        stETHInstance = IERC20(_stETH);
        frxETHInstance = IERC20(_frxETH);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposit into pool
    function deposit(address _ethContract, uint256 _amount) external {
        require(_ethContract != address(0), "No Zero Address");
        require(
            _amount >= minDeposit && _amount <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        depositTimes[msg.sender] = block.timestamp;
        userBalance[msg.sender] += _amount;

        if (_ethContract == stETH) {
            userTo_stETHBalance[msg.sender] += _amount;
            stETHInstance.transferFrom(msg.sender, address(this), _amount);
        }
        if (_ethContract == rETH) {
            userTo_rETHBalance[msg.sender] += _amount;
            rETHInstance.transferFrom(msg.sender, address(this), _amount);
        }

        if (_ethContract == frxETH) {
            userTo_frxETHBalance[msg.sender] += _amount;
            frxETHInstance.transferFrom(msg.sender, address(this), _amount);
        }

        emit Deposit(msg.sender, _amount);
    }

    /// @notice withdraw from pool
    function withdraw() public payable {
        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender];

        uint256 balance = userBalance[msg.sender];
        uint256 rETHbal = userTo_rETHBalance[msg.sender];
        uint256 stETHbal = userTo_stETHBalance[msg.sender];
        uint256 frxETHbal = userTo_frxETHBalance[msg.sender];

        depositTimes[msg.sender] = 0;
        userBalance[msg.sender] = 0;
        userTo_rETHBalance[msg.sender] = 0;
        userTo_stETHBalance[msg.sender] = 0;
        userTo_frxETHBalance[msg.sender] = 0;

        if (duration != 0 && lengthOfDeposit > duration) {
            userPoints[msg.sender] +=
                (calculateUserPoints(balance, lengthOfDeposit)) *
                multiplier;
        } else {
            userPoints[msg.sender] += calculateUserPoints(
                balance,
                lengthOfDeposit
            );
        }

        rETHInstance.transfer(msg.sender, rETHbal);
        stETHInstance.transfer(msg.sender, stETHbal);
        frxETHInstance.transfer(msg.sender, frxETHbal);

        emit Withdrawn(msg.sender, balance, lengthOfDeposit);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function calculateUserPoints() public view returns (uint256) {

        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender]; 
        uint256 numberOfMultiplierMilestones = lengthOfDeposit / 864000;
        uint256 multiplier = (numberOfMultiplierMilestones * multiplierCoefficient) + 1;

        return ((Math.sqrt(userBalance[msg.sender]) * lengthOfDeposit) / SCALE) * multiplier;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}
}
