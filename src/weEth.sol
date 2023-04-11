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

    /// @notice Wraps eEth
    /// @param _eETHAmount the amount of eEth to wrap
    /// @return returns the amount of weEth the user recieves
    function wrap(uint256 _eETHAmount) external returns (uint256) {
        require(_eETHAmount > 0, "wstETH: can't wrap zero stETH");
        //uint256 weEthAmount = eEth.getSharesByPooledEth(_eETHAmount);
        //_mint(msg.sender, weEthAmount);
        //eEth.transferFrom(msg.sender, address(this), _eETHAmount);
        //return weEthAmount;
    }

    /// @notice Unwraps weEth
    /// @param _weETHAmount the amount of weEth to unwrap
    /// @return returns the amount of eEth the user recieves
    function unwrap(uint256 _weETHAmount) external returns (uint256) {
        require(_weETHAmount > 0, "Cannot wrap a zero amount");
        //uint256 eEthAmount = eEth.getPooledEthByShares(_weETHAmount);
        //_burn(msg.sender, _weETHAmount);
        //eEth.transfer(msg.sender, eEthAmount);
        //return eEthAmount;
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
