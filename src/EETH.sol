// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EETH is ERC20 {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    
    address public liquidityPool;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(address _liquidityPool) ERC20("EtherFi ETH", "eETH") {
        liquidityPool = _liquidityPool;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice function to mint eETH
    /// @dev only able to mint from LiquidityPool contract
    function mint(address _account, uint256 _amount) external onlyPoolContract {
        _mint(_account, _amount);
    }

    /// @notice function to burn eETH
    /// @dev only able to burn from LiquidityPool contract
    function burn(address _account, uint256 _amount) external onlyPoolContract {
        _burn(_account, _amount);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyPoolContract() {
        require(msg.sender == liquidityPool, "Only pool contract function");
        _;
    }
}
