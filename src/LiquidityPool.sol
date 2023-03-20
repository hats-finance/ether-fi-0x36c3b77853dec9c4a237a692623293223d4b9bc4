// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IEETH.sol";
import "lib/forge-std/src/console.sol";

contract LiquidityPool {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public eETH;
    address public owner;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event Received(address indexed sender, uint256 value);
    event TokenAddressChanged(address indexed newAddress);
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice initializes owner address
    /// @param _owner address of owner
    constructor(address _owner) {
        owner = _owner;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice sets the contract address for eETH
    /// @dev can't do it in constructor due to circular dependencies
    /// @param _eETH address of eETH contract
    function setTokenAddress(address _eETH) external {
        eETH = _eETH;
        emit TokenAddressChanged(_eETH);
    }

    /// @notice deposit into pool
    /// @dev mints the amount of eTH 1:1 with ETH sent
    function deposit(address _user) external payable {
        IEETH(eETH).mint(_user, msg.value);
        emit Deposit(_user, msg.value);
    }

    /// @notice withdraw from pool
    /// @dev Burns user balance from msg.senders account & Sends equal amount of ETH back to user
    /// @param _amount the amount to withdraw from contract
    function withdraw(uint256 _amount) external payable {
        require(
            IERC20(eETH).balanceOf(msg.sender) >= _amount,
            "Not enough eETH"
        );

        IEETH(eETH).burn(msg.sender, _amount);
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        emit Withdraw(msg.sender, msg.value);
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
