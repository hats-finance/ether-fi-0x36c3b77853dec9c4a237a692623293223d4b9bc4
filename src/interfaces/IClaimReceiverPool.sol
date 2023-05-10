// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IClaimReceiverPool {
    function deposit(uint256 _rEthBal, uint256 _wstEthBal, uint256 _sfrxEthBal, uint256 _cbEthBal, uint256 _points, bytes32[] calldata _merkleProof, uint256 _slippageLimit) external payable;

    function setLiquidityPool(address _liquidityPoolAddress) external;
}
