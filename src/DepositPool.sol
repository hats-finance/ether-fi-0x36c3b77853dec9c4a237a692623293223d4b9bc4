// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DepositPool {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    uint256 depositStandard = 100000000000000000;
    mapping(address => uint256) public depositTimes;
    mapping(address => uint256) public userBalance;
    mapping(address => uint256) public userPoints;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);

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

        uint256 lengthOfWithdrawal = block.timestamp - depositTimes[msg.sender];
        uint256 balance = userBalance[msg.sender];

        depositTimes[msg.sender] = 0;
        userBalance[msg.sender] = 0;
        userPoints[msg.sender] += calculateUserPoints(balance, lengthOfWithdrawal);

        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Failed to send Ether");
        
        emit Withdraw(msg.sender, msg.value);
    }

    function calculateUserPoints(uint256 _depositAmount, uint256 _numberOfSeconds) internal view returns (uint256) {

        uint256 numberOfDepositStandards = _depositAmount / depositStandard;
        return numberOfDepositStandards * _numberOfSeconds;
    }
}
