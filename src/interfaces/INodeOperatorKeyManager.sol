// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface INodeOperatorKeyManager {
    struct KeyData {
        uint128 totalKeys;
        uint128 keysUsed;
        string ipfsHash;
    }

    function registerNodeOperator(string memory ipfsHash, uint128 totalKeys)
        external;
}
