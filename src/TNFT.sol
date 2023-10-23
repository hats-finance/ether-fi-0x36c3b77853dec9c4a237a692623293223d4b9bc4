// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract TNFT is ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------
    address public stakingManagerAddress;
    address public etherFiNodesManagerAddress;

    address public admin;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize to set variables on deployment
    function initialize(address _stakingManagerAddress) initializer external {
        require(_stakingManagerAddress != address(0), "No zero addresses");
        
        __ERC721_init("Transferrable NFT", "TNFT");
        __Ownable_init();
        __UUPSUpgradeable_init();

        stakingManagerAddress = _stakingManagerAddress;
    }

    /// @notice Mints NFT to required user
    /// @dev Only through the staking contract and not by an EOA
    /// @param _receiver Receiver of the NFT
    /// @param _validatorId The ID of the NFT
    function mint(address _receiver, uint256 _validatorId) external onlyStakingManager {
        _mint(_receiver, _validatorId);
    }

    function burnFromWithdrawal(uint256 _validatorId) external onlyEtherFiNodesManager {
        _burn(_validatorId);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setEtherFiNodesManagerAddress(address _addr) external onlyAdmin {
        etherFiNodesManagerAddress = _addr;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Fetches the address of the implementation contract currently being used by the proxy
    /// @return the address of the currently used implementation contract
    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //------------------------------------  MODIFIERS  -------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    modifier onlyStakingManager() {
        require(msg.sender == stakingManagerAddress, "Only staking manager contract");
        _;
    }

    modifier onlyEtherFiNodesManager() {
        require(msg.sender == etherFiNodesManagerAddress, "Only etherFiNodesManager contract");
        _;
    }
}
