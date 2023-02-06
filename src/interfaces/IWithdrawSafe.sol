// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawSafe {

    function setUpNewStake(
        address _nodeOperator, 
        address _tnftHolder, 
        address _bnftHolder) external;
    
}
