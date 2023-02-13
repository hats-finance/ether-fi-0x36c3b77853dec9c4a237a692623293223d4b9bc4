// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract Registration {
    // user address => IPFS hash => number of keys
    mapping(address => mapping(bytes => uint256)) userToKeys;

    // user address => IPFS hash => number of keys available
    mapping(address => mapping(bytes => uint256)) userToKeysLeft;
}
