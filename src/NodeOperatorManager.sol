// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/INodeOperatorManager.sol";
import "../src/interfaces/IAuctionManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/forge-std/src/console.sol";

/// TODO Test whitelist bidding in auction
/// TODO Test permissionless bidding in auction

contract NodeOperatorManager is INodeOperatorManager, Ownable {
    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event OperatorRegistered(uint64 totalKeys, uint64 keysUsed, bytes ipfsHash);
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IAuctionManager auctionMangerInterface;
    address auctionContractAddress;
    bytes32 public merkleRoot;

    // user address => OperaterData Struct
    mapping(address => KeyData) public addressToOperatorData;
    mapping(address => bool) private whitelistedAddresses;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function registerNodeOperator(
        bytes32[] calldata _merkleProof,
        bytes memory _ipfsHash,
        uint64 _totalKeys
    ) public {
        addressToOperatorData[msg.sender] = KeyData({
            totalKeys: _totalKeys,
            keysUsed: 0,
            ipfsHash: abi.encodePacked(_ipfsHash)
        });

        _verifyWhitelistedAddress(msg.sender, _merkleProof);
        emit OperatorRegistered(
            addressToOperatorData[msg.sender].totalKeys,
            addressToOperatorData[msg.sender].keysUsed,
            _ipfsHash
        );
    }

    function fetchNextKeyIndex(address _user) external returns (uint64) {
        require(msg.sender == auctionContractAddress, "Only auction contract function");
        uint64 totalKeys = addressToOperatorData[_user].totalKeys;
        require(
            addressToOperatorData[_user].keysUsed < totalKeys,
            "Insufficient public keys"
        );

        uint64 ipfsIndex = addressToOperatorData[_user].keysUsed;
        addressToOperatorData[_user].keysUsed++;
        return ipfsIndex;
    }

    /// @notice Updates the merkle root whitelists have been updated
    /// @dev merkleroot gets generated in JS offline and sent to the contract
    /// @param _newMerkle new merkle root to be used for bidding
    function updateMerkleRoot(bytes32 _newMerkle) external onlyOwner {
        bytes32 oldMerkle = merkleRoot;
        merkleRoot = _newMerkle;

        emit MerkleUpdated(oldMerkle, _newMerkle);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  GETTERS   ---------------------------------------
    //--------------------------------------------------------------------------------------

    function getUserTotalKeys(address _user) external view returns (uint64 totalKeys) {
        totalKeys = addressToOperatorData[_user].totalKeys;
    }

    function getNumKeysRemaining(address _user) external view returns (uint64 numKeysRemaining) {
        numKeysRemaining = addressToOperatorData[_user].totalKeys - addressToOperatorData[_user].keysUsed;
    }

    function isWhitelisted(address _user) public view returns (bool whitelisted) {
        whitelisted = whitelistedAddresses[_user];
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  SETTERS   ---------------------------------------
    //--------------------------------------------------------------------------------------

    function setAuctionContractAddress(address _auctionContractAddress) public onlyOwner {
        auctionMangerInterface = IAuctionManager(_auctionContractAddress);
        auctionContractAddress = _auctionContractAddress;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _verifyWhitelistedAddress(
        address _user,
        bytes32[] calldata _merkleProof
    ) internal returns (bool whitelisted) {
        whitelisted = MerkleProof.verify(
            _merkleProof,
            merkleRoot,
            keccak256(abi.encodePacked(_user))
        );
        if (whitelisted) {
            whitelistedAddresses[_user] = true;
        }
    }
}
