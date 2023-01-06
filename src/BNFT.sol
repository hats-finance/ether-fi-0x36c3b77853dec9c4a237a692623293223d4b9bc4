// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BNFT is ERC721 {

//--------------------------------------------------------------------------------------
//---------------------------------  STATE-VARIABLES  ----------------------------------
//--------------------------------------------------------------------------------------
  
    uint256 private tokenIds;
    uint256 public nftValue = 2 ether;
    address public depositContractAddress;
    address public owner;

//--------------------------------------------------------------------------------------
//----------------------------------  CONSTRUCTOR   ------------------------------------
//--------------------------------------------------------------------------------------
   
    constructor(address _owner) ERC721("Bond NFT", "BNFT") {
        depositContractAddress = msg.sender;
        owner = _owner;
    }

//--------------------------------------------------------------------------------------
//----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
//--------------------------------------------------------------------------------------
    
    function mint(address _reciever) external onlyDepositContract {
        _safeMint(_reciever, tokenIds);
        unchecked {
            tokenIds++;
        }
    }

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

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}
