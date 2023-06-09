// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IRegulationsManager.sol";

contract RegulationsManager is
    IRegulationsManager,
    Initializable,
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    mapping(uint32 => mapping(address => bool)) public isEligible;
    mapping(address => bytes32) public declarationHashes;
    mapping(uint256 => bytes32) public correctVersionHash;

    uint32 public whitelistVersion;

    uint256[7] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event EligibilityConfirmed(uint32 whitelistVersion, bytes32 hash, address user);
    event EligibilityRemoved(uint32 whitelistVersion, address user);
    event whitelistVersionIncreased(uint32 currentDeclaration);

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /// @notice initializes contract
    function initialize() external initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /// @notice sets a user apart of the whitelist, confirming they are not in a blacklisted country
    function confirmEligibility(bytes32 _hash) external whenNotPaused {
        require(correctVersionHash[whitelistVersion] == _hash, "Incorrect hash");
        isEligible[whitelistVersion][msg.sender] = true;
        declarationHashes[msg.sender] = keccak256(abi.encodePacked(_hash, msg.sender));

        emit EligibilityConfirmed(whitelistVersion, _hash, msg.sender);
    }

    /// @notice removes a user from the whitelist
    /// @dev can be called by the owner or the user themself
    /// @param _user the user to remove from the whitelist
    function removeFromWhitelist(address _user) external whenNotPaused {
        require(
            msg.sender == _user || msg.sender == owner(),
            "Incorrect Caller"
        );
        require(
            isEligible[whitelistVersion][_user] == true,
            "User is not whitelisted"
        );

        isEligible[whitelistVersion][_user] = false;

        emit EligibilityRemoved(whitelistVersion, _user);
    }

    /// @notice resets the whitelist by incrementing the iteration
    /// @dev happens when there is an update to the blacklisted country list
    function initializeNewWhitelist(bytes32 _newVersionHash) external onlyOwner {
        whitelistVersion++;
        correctVersionHash[whitelistVersion] = _newVersionHash;

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
