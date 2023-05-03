// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

import "./interfaces/IEETH.sol";
import "./interfaces/ILiquidityPool.sol";

contract EETH is IERC20Upgradeable, UUPSUpgradeable, OwnableUpgradeable, IEETH {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    ILiquidityPool public liquidityPool;

    uint256 public totalShares;
    mapping (address => uint256) public shares;
    mapping (address => mapping (address => uint256)) public allowances;

    uint256[46] __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @return the name of the token.
     */
    function name() public pure returns (string memory) {
        return "ether.fi ETH";
    }

    /**
     * @return the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure returns (string memory) {
        return "eETH";
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function initialize(address _liquidityPool) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        liquidityPool = ILiquidityPool(_liquidityPool);
    }

    function mintShares(address _user, uint256 _share) external onlyPoolContract {
        shares[_user] += _share;
        totalShares += _share;
    }

    function burnShares(address _user, uint256 _share) external onlyPoolContract {
        shares[_user] -= _share;
        totalShares -= _share;
    }

    // IERC20 functions

    function totalSupply() public view returns (uint256) {
        return liquidityPool.getTotalPooledEther();
    }

    function balanceOf(address _user) public view override(IEETH, IERC20Upgradeable) returns (uint256) {
        return liquidityPool.getTotalEtherClaimOf(_user);
    }

    function transfer(address _recipient, uint256 _amount) external override(IEETH, IERC20Upgradeable) returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override(IEETH, IERC20Upgradeable) returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS  ---------------------------------
    //--------------------------------------------------------------------------------------

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = liquidityPool.sharesForAmount(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        require(_sharesAmount <= shares[_sender], "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        shares[_sender] -= _sharesAmount;
        shares[_recipient] += _sharesAmount;
    }

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
        require(msg.sender == address(liquidityPool), "Only pool contract function");
        _;
    }
}
