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
    // bytes256: a byte stream of user score + etc
    mapping(string => mapping(address => bytes)) public scores;
    mapping(address => bool) public allowedCallers;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event ScoreSet(address user, string category, bytes data);
    event CallerStatusUpdated(address user, bool status);

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
        bytes memory _score
    ) external allowedCaller(msg.sender) notAddressZero(_user) {
        scores[_name][_user] = _score;
        emit ScoreSet(_user, _name, _score);
    }

    /// @notice updates the status of a caller
    /// @param _caller the address of the contract or EOA that is being updated
    function switchCallerStatus(address _caller) external onlyOwner notAddressZero(_caller) {
        if(allowedCallers[_caller] == true) {
            allowedCallers[_caller] = false;
        }else {
            allowedCallers[_caller] = true;
        }

        emit CallerStatusUpdated(_caller, allowedCallers[_caller]);
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

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier allowedCaller(address _caller) {
        require(allowedCallers[_caller], "Caller not permissioned");
        _;
    }

    modifier notAddressZero(address _user) {
        require(_user != address(0), "Cannot be address zero");
        _;
    }
}
