// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract BNFT is ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public stakingManagerAddress;
    uint256[49] public __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize(address _stakingManagerAddress) initializer external {
        __ERC721_init("Bond NFT", "BNFT");
        __Ownable_init();
        __UUPSUpgradeable_init();

        stakingManagerAddress = _stakingManagerAddress;
    }

    /// @notice Mints NFT to required user
    /// @dev Only through the staking contratc and not by an EOA
    /// @param _reciever receiver of the NFT
    /// @param _validatorId the ID of the NFT
    function mint(address _reciever, uint256 _validatorId) external onlyStakingManager {
        _safeMint(_reciever, _validatorId);
    }

    //ERC721 transfer function being overidden to make it soulbound
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721Upgradeable) {
        require(from == address(0), "Err: token is SOUL BOUND");
        super.transferFrom(from, to, tokenId);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //------------------------------------  MODIFIERS  -------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManager() {
        require(msg.sender == stakingManagerAddress, "Only staking manager contract");
        _;
    }
}
