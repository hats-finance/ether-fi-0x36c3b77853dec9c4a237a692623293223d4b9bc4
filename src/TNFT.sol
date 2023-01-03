// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TNFT is ERC721 {

    constructor() ERC721("Transferrable NFT", "TNFT"){
        
    }
    
}