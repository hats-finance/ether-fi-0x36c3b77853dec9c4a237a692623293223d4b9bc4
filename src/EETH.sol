// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "./interfaces/IEETH.sol";

contract EETH is ERC20Upgradeable, IEETH {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    
    address public liquidityPool;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize(address _liquidityPool) external initializer {
        __ERC20_init("EtherFi ETH", "eETH");
        liquidityPool = _liquidityPool;
    }

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
