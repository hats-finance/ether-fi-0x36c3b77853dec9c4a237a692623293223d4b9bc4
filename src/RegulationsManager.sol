// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IRegulationsManager.sol";

contract RegulationsManager is
    IRegulationsManager,
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    mapping(uint32 => mapping (address => bool)) public isEligible;
    mapping(uint32 => mapping (address => bytes32)) public declarationHash;

    uint32 public whitelistVersion;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event EligibilityConfirmed(bytes32 declarationHash, uint32 whitelistVersion, address user);
    event EligibilityRemoved(uint32 whitelistVersion, address user);
    event whitelistVersionIncreased(uint32 currentDeclaration);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice initializes contract
    function initialize() external initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    /// @notice sets a user apart of the whitelist, confirming they are not in a blacklisted country
    /// @param _declarationHash hash of the agreement the user signed containing blacklisted countries
    function confirmEligibility(bytes32 _declarationHash) external whenNotPaused {
        isEligible[whitelistVersion][msg.sender] = true;
        declarationHash[whitelistVersion][msg.sender] = _declarationHash;

        emit EligibilityConfirmed(_declarationHash, whitelistVersion, msg.sender);
    }

    /// @notice removes a user from the whitelist
    /// @dev can be called by the owner or the user themself
    /// @param _user the user to remove from the whitelist
    function removeFromWhitelist(address _user) external whenNotPaused {
        require(msg.sender == _user || msg.sender == owner(), "Incorrect Caller");
        require(isEligible[whitelistVersion][_user] == true, "User not whitelisted");

        isEligible[whitelistVersion][_user] = false;

        emit EligibilityRemoved(whitelistVersion, _user);
    }

    /// @notice resets the whitelist by incrementing the iteration
    /// @dev happens when there is an update to the blacklisted country list
    function resetWhitelist() external onlyOwner {
        whitelistVersion++;

        emit whitelistVersionIncreased(whitelistVersion);
    }

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
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

  
}
