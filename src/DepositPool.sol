// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/forge-std/src/console.sol";

contract DepositPool is Ownable {
    /// TODO  min amount of deposit, 0.1 ETH, max amount, 100 ETH
    /// TODO multiplier for points, after x months, the points double, where x is configurable
    /// TODO numberOfDepositStandards should be square root of deposited eth amount
    /// the more you deposit, the more points you get

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 public constant depositStandard = 100000000000000000;
    uint256 public constant SCALE = 100;
    mapping(address => uint256) public depositTimes;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public userPoints;

    uint256 public immutable minDeposit = 0.1 ether;
    uint256 public immutable maxDeposit = 100 ether;
    uint256 public immutable multiplier = 2;

    // Number of months after which points double
    uint256 public duration;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(
        address indexed sender,
        uint256 amount,
        uint256 lengthOfDeposit
    );
    event DurationSet(uint256 oldDuration, uint256 newDuration);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposit into pool
    function deposit() external payable {
        require(msg.value >= 0.1 ether, "Deposit too small");
        depositTimes[msg.sender] = block.timestamp;
        userBalance[msg.sender] = msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    /// @notice withdraw from pool
    function withdraw() public payable {
        uint256 lengthOfDeposit = block.timestamp - depositTimes[msg.sender];
        uint256 balance = userBalance[msg.sender];

        depositTimes[msg.sender] = 0;
        userBalance[msg.sender] = 0;
        userPoints[msg.sender] += calculateUserPoints(balance, lengthOfDeposit);

        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");

        emit Withdraw(msg.sender, msg.value, lengthOfDeposit);
    }

    function setDuration(uint256 _months) public onlyOwner {
        uint256 oldDuration = duration;
        duration = _months;
        emit DurationSet(oldDuration, duration);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function calculateUserPoints(
        uint256 _depositAmount,
        uint256 _numberOfSeconds
    ) internal pure returns (uint256) {
        uint256 numberOfDepositStandards = (_depositAmount * SCALE) /
            depositStandard;
        return (numberOfDepositStandards * _numberOfSeconds) / SCALE;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}
}
