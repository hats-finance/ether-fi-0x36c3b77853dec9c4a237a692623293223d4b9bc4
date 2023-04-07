// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IScoreManager {
    // the type of score
    enum SCORE_TYPE {
        EarlyAdopterPool
    }

   function setScore(
        SCORE_TYPE _type,
        address _user,
        bytes32 _score
    ) external;

    function setCallerStatus(address _caller, bool _flag) external;
    
}
