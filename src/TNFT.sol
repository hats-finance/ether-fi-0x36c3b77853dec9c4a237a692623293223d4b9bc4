// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

contract TNFT is ERC721Upgradeable {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public stakingManagerContractAddress;

    uint256[32] __gap;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize() initializer external {
        __ERC721_init("Transferrable NFT", "TNFT");
        stakingManagerContractAddress = msg.sender;
    }

    /// @notice Mints NFT to required user
    /// @dev Only through the staking contratc and not by an EOA
    /// @param _reciever receiver of the NFT
    /// @param _validatorId the ID of the NFT
    function mint(address _reciever, uint256 _validatorId) external onlyStakingManagerContract {
        _safeMint(_reciever, _validatorId);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContractAddress,
            "Only staking mananger contract function"
        );
        _;
    }
}