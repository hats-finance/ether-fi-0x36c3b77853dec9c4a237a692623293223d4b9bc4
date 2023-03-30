// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ITNFT {
    function initialize() external;
    function mint(address _reciever, uint256 _validatorId) external;
}
