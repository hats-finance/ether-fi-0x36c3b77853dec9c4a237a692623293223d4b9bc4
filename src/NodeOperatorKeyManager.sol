// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/INodeOperatorKeyManager.sol";

contract NodeOperatorKeyManager is INodeOperatorKeyManager {
    event OperatorRegistered(
        uint64 totalKeys,
        uint64 keysUsed,
        string ipfsHash
    );

    // user address => OperaterData Struct
    mapping(address => KeyData) public addressToOperatorData;

    function increaseKeysIndex(address _user) public {
        addressToOperatorData[_user].keysUsed++;
    }

    function registerNodeOperator(string memory _ipfsHash, uint64 _totalKeys)
        public
    {
        addressToOperatorData[msg.sender] = KeyData({
            totalKeys: _totalKeys,
            keysUsed: 0,
            ipfsHash: abi.encodePacked(_ipfsHash)
        });
        emit OperatorRegistered(
            addressToOperatorData[msg.sender].totalKeys,
            addressToOperatorData[msg.sender].keysUsed,
            _ipfsHash
        );
    }

    //------- VIEW FUNCTIONS ------//
    function getNumberOfKeysUsed(address _user)
        public
        view
        returns (uint256 keysUsed)
    {
        keysUsed = addressToOperatorData[_user].keysUsed;
    }

    function getTotalKeys(address _user)
        public
        view
        returns (uint256 totalKeys)
    {
        totalKeys = addressToOperatorData[_user].totalKeys;
    }
}
