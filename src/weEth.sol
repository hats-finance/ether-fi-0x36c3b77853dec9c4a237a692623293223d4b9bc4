// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "./interfaces/IEETH.sol";

contract EETH is ERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable, ERC20PermitUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IEETH eEth;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize(address _eEth) external initializer {
        __ERC20_init("EtherFi wrapped ETH", "weETH");
        __ERC20Permit_init("EtherFi wrapped ETH");
        __UUPSUpgradeable_init();
        __Ownable_init();
        eEth = IEETH(_eEth);
    }

    /// @notice function to mint eETH
    /// @dev only able to mint from LiquidityPool contract
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }

    /// @notice function to burn eETH
    /// @dev only able to burn from LiquidityPool contract
    function burn(address _account, uint256 _amount) external {
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
}
