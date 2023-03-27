// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BNFT is ERC721 {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    address public stakingManagerContractAddress;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor() ERC721("Bond NFT", "BNFT") {
        stakingManagerContractAddress = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Function only allows the staking manager contract to mint to prevent
    //standard eoa minting themselves NFTs
    function mint(address _reciever, uint256 _validatorId) external onlyStakingManagerContract {
        _safeMint(_reciever, _validatorId);
    }

    //ERC721 transfer function being overidden to make it soulbound
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721) {
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