// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {
    function withdrawFunds(
        address _treasury,
        uint256 _treasuryAmount,
        address _operator,
        uint256 _operatorAmount,
        address _tnftHolder,
        uint256 _tnftAmount,
        address _bnftHolder,
        uint256 _bnftAmount
    ) external;

    function verySafeMoveToManager(address _manager) external;
    function updateSweptRewards(uint256 amount) external;

}
