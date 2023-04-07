// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IScoreManager {

   function setScore(
        string memory _name,
        address _user,
        bytes memory _score
    ) external;

    function switchCallerStatus(address _caller) external;
    
}
