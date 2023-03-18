// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface INodeOperatorKeyManager {
    struct KeyData {
        uint64 totalKeys;
        uint64 keysUsed;
        bytes ipfsHash;
    }

    function registerNodeOperator(
        bytes32[] calldata _merkleProof,
        string memory ipfsHash,
        uint64 totalKeys
    ) external;

    function fetchNextKeyIndex(address _user) external returns (uint64);

    function getUserTotalKeys(
        address _user
    ) external view returns (uint64 totalKeys);
}
