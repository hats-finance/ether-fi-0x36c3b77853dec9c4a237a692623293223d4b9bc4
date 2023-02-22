// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILiquidityPool {
    function getTokenAddress() external returns (address);
    function setTokenAddress(address _eETH) external;
    function deposit() external payable;
    function withdraw(uint256 _amount) external payable;
}