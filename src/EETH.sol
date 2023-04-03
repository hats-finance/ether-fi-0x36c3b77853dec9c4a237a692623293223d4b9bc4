// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IEETH.sol";

contract EETH is ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable, IEETH {
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
        __UUPSUpgradeable_init();
        __Ownable_init();
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
    //-------------------------------  INTERNAL FUNCTIONS  ---------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //------------------------------------  GETTERS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyPoolContract() {
        require(msg.sender == liquidityPool, "Only pool contract function");
        _;
    }
}
