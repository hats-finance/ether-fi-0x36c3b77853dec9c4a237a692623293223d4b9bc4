// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IScoreManager {
    // the type of score
    enum SCORE_TYPE {
        EarlyAdopterPool
    }
    
    function scores(SCORE_TYPE _type, address _user) external view returns (bytes32);
    function totalScores(SCORE_TYPE _type) external view returns (bytes32);

    function setScore(
        SCORE_TYPE _type,
        address _user,
        bytes32 _score
    ) external;

    function setTotalScore(
        SCORE_TYPE _type,
        bytes32 _totalScore
    ) external;

    function setCallerStatus(address _caller, bool _flag) external;
    
}
