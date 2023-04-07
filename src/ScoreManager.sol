// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract ScoreManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // string: indicate the type of the score (like the name of the promotion)
    // address: user wallet address
    // bytes32: a byte stream of user score + etc
    mapping(string => mapping(address => bytes32)) public scores;
    mapping(address => bool) public allowedCallers;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event ScoreSet(address user, string category, bytes32 data);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice initialize to set variables on deployment
    /// @dev Deploys NFT contracts internally to ensure ownership is set to this contract
    /// @dev AuctionManager contract must be deployed first
    function initialize() external initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    /// @notice sets the score of a user
    /// @dev will be called by approved contracts that can set reward totals
    /// @param _name the name of the category
    /// @param _user the user to fetch the score for
    /// @param _score the score the user will receive in bytes form
    function setScore(
        string memory _name,
        address _user,
        bytes32 _score
    ) external allowedCaller(msg.sender) nonZeroAddress(_user) {
        scores[_name][_user] = _score;
        emit ScoreSet(_user, _name, _score);
    }

    /// @notice updates the status of a caller
    /// @param _caller the address of the contract or EOA that is being updated
    /// @param _flag the bool value to update by
    function setCallerStatus(address _caller, bool _flag) external onlyOwner nonZeroAddress(_caller) {
        allowedCallers[_caller] = _flag;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
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

    modifier allowedCaller(address _caller) {
        require(allowedCallers[_caller], "Caller not permissioned");
        _;
    }

    modifier nonZeroAddress(address _user) {
        require(_user != address(0), "Cannot be address zero");
        _;
    }
}
