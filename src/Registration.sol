// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract Registration {

    // user address => IPFS hash
    mapping(address => bytes) public addressToIpfsHash;

    // user address => IPFS hash => number of keys
    mapping(address => uint256) public numberOfKeysUsed;

    function increaseKeysIndex(address _user) public {
        numberOfKeysUsed[_user]++;
    }
}
