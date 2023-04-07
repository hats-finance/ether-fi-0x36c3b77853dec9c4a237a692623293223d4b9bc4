// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IScoreManager {

   function setScore(
        string memory _name,
        address _user,
        bytes32 _score
    ) external;

    function setCallerStatus(address _caller, bool _flag) external;
    
}
