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

    function registerNodeOperator(
        string memory _ipfsHash,
        uint64 _totalKeys
    ) public {
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
}
