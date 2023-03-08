// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface INodeOperatorKeyManager {
    struct KeyData {
        uint64 totalKeys;
        uint64 keysUsed;
        bytes32 ipfsHash;
    }

    function registerNodeOperator(string memory ipfsHash, uint64 totalKeys)
        external;

    function getNumberOfKeysUsed(address _user)
        external
        view
        returns (uint256 keysUsed);
}
