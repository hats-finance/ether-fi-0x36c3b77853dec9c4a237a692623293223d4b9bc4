// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
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
    mapping(address => bytes) public userIsoCode;
    mapping(address => string) public declarationHash;

    uint32 public declarationIteration;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event EligibilityConfirmed(bytes isoCode, string declarationHash, uint32 declarationIteration, address user);
    event EligibilityRemoved(uint32 declarationIteration, address user);
    event DeclarationIterationIncreased(uint32 currentDeclaration);

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

    function confirmEligibility(bytes memory _isoCode, string memory _declarationHash) external {
        require(_isoCode.length == 2, "Invalid IDO Code");

        isEligible[declarationIteration][msg.sender] = true;
        userIsoCode[msg.sender] = _isoCode;
        declarationHash[msg.sender] = _declarationHash;

        emit EligibilityConfirmed(_isoCode, _declarationHash, declarationIteration, msg.sender);

    }

    function removeFromWhitelist(address _user) external {
        require(msg.sender == _user || msg.sender == owner());
        require(isEligible[declarationIteration][_user] == true, "User not whitelisted");

        isEligible[declarationIteration][_user] = false;

        emit EligibilityRemoved(declarationIteration, _user);
    }

    function resetWhitelist() external onlyOwner {
        declarationIteration++;

        emit DeclarationIterationIncreased(declarationIteration);
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
