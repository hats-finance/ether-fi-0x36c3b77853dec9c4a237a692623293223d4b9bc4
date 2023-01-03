// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BNFT is ERC721 {
    
    uint256 private tokenId;
    uint256 public nftValue = 2 ether;

    address public depositContractAddress;
    address public owner;

    event UpdateNftValue(uint256 oldNftValue, uint256 newNftValue);

    constructor(address _owner) ERC721("Bond NFT", "BNFT") {
        depositContractAddress = msg.sender;
        owner = _owner;
    }

    function mint(address _reciever) external onlyDepositContract {
        _safeMint(_reciever, tokenId);
        unchecked {
            tokenId++;
        }
    }

    function setNftValue(uint256 _newNftValue) public onlyOwner {
        uint256 oldNftValue = nftValue;
        nftValue = _newNftValue;

        emit UpdateNftValue(oldNftValue, _newNftValue);
    }

    modifier onlyDepositContract() {
        require(msg.sender == depositContractAddress, "Only deposit contract function");
        _;
    }

     modifier onlyOwner() {
        require(msg.sender == owner, "Only owner function");
        _;
    }
}
