// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IDeposit {
    function deposit() external payable;

    function setStakeAmount(uint256 _newStakeAmount) external;
}
