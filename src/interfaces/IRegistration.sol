// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegistration {
    struct OperatorData {
        string ipfsHash;
        uint256 totalKeys;
        uint256 keysUsed;
    }

    function registerNodeOperator(string memory ipfsHash, uint256 totalKeys)
        external;
}
