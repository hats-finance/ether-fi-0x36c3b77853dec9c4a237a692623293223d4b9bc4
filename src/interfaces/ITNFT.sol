// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITNFT {

    function mint(address _reciever) external;
    function setNftValue(uint256 _newNftValue) external;
}