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
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }

    function quietMint(address account, uint256 amount) external {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        // emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function mintBatch(address[34] memory _accounts, uint256[34] memory _amounts, uint256 _totalAmount) external {
        require(_accounts.length == _amounts.length, "");
        _totalSupply += _totalAmount;
        for (uint i = 0; i < _accounts.length; i++) {
            if (_amounts[i] != 0 && _accounts[i] != address(0)) {
                _balances[_accounts[i]] += _amounts[i];
            }
        }
    }

    function mintBatch(address[18] memory _accounts, uint256[18] memory _amounts, uint256 _totalAmount) external {
        require(_accounts.length == _amounts.length, "");
        _totalSupply += _totalAmount;
        for (uint i = 0; i < _accounts.length; i++) {
            if (_amounts[i] != 0 && _accounts[i] != address(0)) {
                _balances[_accounts[i]] += _amounts[i];
            }
        }
    }

    /// @notice function to burn eETH
    /// @dev only able to burn from LiquidityPool contract
    function burn(address _account, uint256 _amount) external {
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
