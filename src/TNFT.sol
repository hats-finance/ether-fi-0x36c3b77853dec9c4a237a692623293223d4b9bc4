// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TNFT is ERC721 {

    uint256 private tokenId;
    uint256 public price = 30 ether;

    constructor() ERC721("Transferrable NFT", "TNFT"){

    }

    function mint(address _reciever) public {
        _safeMint(_reciever, tokenId);
        unchecked {
           tokenId++;
        }
    }
}