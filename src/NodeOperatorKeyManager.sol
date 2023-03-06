// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/interfaces/INodeOperatorKeyManager.sol";

contract NodeOperatorKeyManager is INodeOperatorKeyManager {
    event OperatorRegistered(
        uint128 totalKeys,
        uint128 keysUsed,
        string ipfsHash
    );

    // user address => OperaterData Struct
    mapping(address => KeyData) public addressToOperatorData;

    function increaseKeysIndex(address _user) public {
        addressToOperatorData[_user].keysUsed++;
    }

    function registerNodeOperator(string memory _ipfsHash, uint128 _totalKeys)
        public
    {
        addressToOperatorData[msg.sender] = KeyData({
            totalKeys: _totalKeys,
            keysUsed: 0,
            ipfsHash: _ipfsHash
        });
        emit OperatorRegistered(
            addressToOperatorData[msg.sender].totalKeys,
            addressToOperatorData[msg.sender].keysUsed,
            addressToOperatorData[msg.sender].ipfsHash
        );
    }
}
