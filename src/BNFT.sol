// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

contract BNFT is ERC721Upgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public stakingManagerContractAddress;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize() initializer external {
        __ERC721_init("Bond NFT", "BNFT");
        stakingManagerContractAddress = msg.sender;
    }

    /// @notice Mints NFT to required user
    /// @dev Only through the staking contratc and not by an EOA
    /// @param _reciever receiver of the NFT
    /// @param _validatorId the ID of the NFT
    function mint(address _reciever, uint256 _validatorId) external onlyStakingManagerContract {
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
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}