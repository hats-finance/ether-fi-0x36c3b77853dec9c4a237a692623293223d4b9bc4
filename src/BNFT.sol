// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BNFT is ERC721, Ownable {

    uint256 private tokenId;
    uint256 public price = 2 ether;

    constructor() ERC721("Bond NFT", "BNFT"){

    }

    function mint(address _reciever) external onlyOwner {
        _safeMint(_reciever, tokenId);
        unchecked {
           tokenId++;
        }
    }
}