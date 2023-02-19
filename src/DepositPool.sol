// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// import "lib/forge-std/src/console.sol";

contract DepositPool is Ownable {
    using Math for uint256;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address private immutable rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private immutable stETH =
        0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private immutable frxETH =
        0x5E8422345238F34275888049021821E8E08CAa1f;

    uint256 public constant depositStandard = 100000000;
    uint256 public constant SCALE = 100;

    // User to time of deposit
    mapping(address => uint256) public depositTimes;

    // user to rETH deposited
    mapping(address => uint256) public userTo_rETHBalance;
    // user to rETH deposited
    mapping(address => uint256) public userTo_stETHBalance;
    //user to frxETH deposited
    mapping(address => uint256) public userTo_frxETHBalance;

    //total user balance
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

    constructor() {
        rETHInstance = IERC20(rETH);
        stETHInstance = IERC20(stETH);
        frxETHInstance = IERC20(frxETH);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposit into pool
    function deposit() external payable {
        require(
            msg.value >= minDeposit && msg.value <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        depositTimes[msg.sender] = block.timestamp;
        userBalance[msg.sender] = msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice withdraw from pool
    function withdraw() public payable {
        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender];
        // console.logUint(lengthOfDeposit);
        uint256 balance = userBalance[msg.sender];

        depositTimes[msg.sender] = 0;
        userBalance[msg.sender] = 0;
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

        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");

        emit Withdrawn(msg.sender, balance, lengthOfDeposit);
    }

    /// @param _months number of months. Will be converted to seconds in function
    function setDuration(uint256 _months) public onlyOwner {
        uint256 oneMonth = 1 weeks * 4;
        uint256 oldDuration = duration;
        duration = _months * oneMonth;
        emit DurationSet(oldDuration, duration);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function calculateUserPoints(
        uint256 _depositAmount,
        uint256 _numberOfSeconds
    ) internal pure returns (uint256) {
        uint256 numberOfDepositStandards = (Math.sqrt(_depositAmount) * SCALE) /
            depositStandard;

        return (numberOfDepositStandards * _numberOfSeconds) / SCALE;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}
}
