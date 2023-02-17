// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "lib/forge-std/src/console.sol";

contract DepositPool {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    uint256 public constant depositStandard = 100000000000000000;
    uint256 public constant SCALE = 100;
    mapping(address => uint256) public depositTimes;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public userPoints;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount, uint256 lengthOfDeposit);

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

    function calculateUserPoints(uint256 _depositAmount, uint256 _numberOfSeconds) internal view returns (uint256) {

        uint256 numberOfDepositStandards = (_depositAmount * SCALE) / depositStandard;
        return (numberOfDepositStandards * _numberOfSeconds) / SCALE;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {
    }
}
