// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/INodeOperatorKeyManager.sol";
import "../src/interfaces/IAuctionManager.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "lib/forge-std/src/console.sol";

/// TODO Combine bid functions in auction contract
/// TODO Tests

contract NodeOperatorKeyManager is INodeOperatorKeyManager, Ownable {
    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event OperatorRegistered(
        uint64 totalKeys,
        uint64 keysUsed,
        string ipfsHash
    );
    event MerkleUpdated(bytes32 oldMerkle, bytes32 indexed newMerkle);

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IAuctionManager auctionMangerInterface;
    bytes32 public merkleRoot;

    // user address => OperaterData Struct
    mapping(address => KeyData) public addressToOperatorData;

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function registerNodeOperator(
        bytes32[] calldata _merkleProof,
        string memory _ipfsHash,
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
        uint64 totalKeys = addressToOperatorData[_user].totalKeys;
        require(
            addressToOperatorData[_user].keysUsed < totalKeys,
            "All public keys used"
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

    function getUserTotalKeys(
        address _user
    ) external view returns (uint64 totalKeys) {
        totalKeys = addressToOperatorData[_user].totalKeys;
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  SETTERS   ---------------------------------------
    //--------------------------------------------------------------------------------------

    function setAuctionContractAddress(
        address _auctionContractAddress
    ) public onlyOwner {
        auctionMangerInterface = IAuctionManager(_auctionContractAddress);
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
            //whitelistedAddresses[_user] = true;
            auctionMangerInterface.whitelistAddress(msg.sender);
        }
    }
}
