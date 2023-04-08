// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IScoreManager.sol";

contract ScoreManager is
    IScoreManager,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // SCORE_TYPE: the type of the score
    // address: user wallet address
    // bytes32: a byte stream of user score + etc
    mapping(SCORE_TYPE => mapping(address => bytes32)) public scores;

    // SCORE_TYPE: the type of the score
    // bytes32: a byte stream of aggregated info of users' scores (e.g., total sum)
    mapping(SCORE_TYPE => bytes32) public totalScores;

    mapping(address => bool) public allowedCallers;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event ScoreSet(address indexed user, SCORE_TYPE score_type, bytes32 data);

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
    /// @param _type the type of the score
    /// @param _user the user to fetch the score for
    /// @param _score the score the user will receive in bytes form
    function setScore(
        SCORE_TYPE _type,
        address _user,
        bytes32 _score
    ) external allowedCaller(msg.sender) nonZeroAddress(_user) {
        scores[_type][_user] = _score;
    }

    /// @notice sets the total score of a score type
    /// @param _type the type of the score
    /// @param _totalScore the total score
    function setTotalScore(
        SCORE_TYPE _type,
        bytes32 _totalScore
    ) external allowedCaller(msg.sender) {
        totalScores[_type] = _totalScore;
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
