// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILiquidityPool {

    function deposit(address _user, uint256 _score) external payable;

}
