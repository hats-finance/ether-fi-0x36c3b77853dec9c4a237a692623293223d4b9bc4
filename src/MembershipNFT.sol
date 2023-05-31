// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

contract MembershipNFT is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable {

    string private contractMetadataURI; /// @dev opensea contract-level metadata
    uint256 public nextMintID;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // TODO(dave): permissions
    function mint(address _to, uint256 _amount) external returns (uint256) {
        uint256 tokenId = nextMintID++;
        _mint(_to, tokenId, _amount, "");
    }

    // TODO(dave): permissions
    function burn(address _from, uint256 _tokenId, uint256 _amount) external {
        _burn(_from, _tokenId, _amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //---------------------------------- NFT METADATA --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @dev ERC-4906 This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev ERC-4906 This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.    
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);


    /// @notice OpenSea contract-level metadata
    function contractURI() public view returns (string memory) {
        return contractMetadataURI;
    }

    /// @dev opensea contract-level metadata
    function setContractMetadataURI(string calldata _newURI) external onlyOwner {
        contractMetadataURI = _newURI;
    }

    /// @dev erc1155 metadata extension
    function setMetadataURI(string calldata _newURI) external onlyOwner {
        _setURI(_newURI);
    }

    /// @dev alert opensea to a metadata update
    function alertMetadataUpdate(uint256 id) public onlyOwner {
        emit MetadataUpdate(id);
    }

    /// @dev alert opensea to a metadata update
    function alertBatchMetadataUpdate(uint256 startID, uint256 endID) public onlyOwner {
        emit BatchMetadataUpdate(startID, endID);
    }

}


