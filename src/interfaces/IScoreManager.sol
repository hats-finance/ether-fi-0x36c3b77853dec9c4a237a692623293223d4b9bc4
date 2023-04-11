// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IScoreManager {
    
    function scores(uint256 _type, address _user) external view returns (bytes32);

    function scoreTypes(uint256 _id) external view returns (bytes memory);

    function typeIds(bytes memory _type) external view returns (uint256);
    
    function totalScores(bytes memory _type) external view returns (bytes32);

    function setScore(
        uint256 _type,
        address _user,
        bytes32 _score
    ) external;

    function setTotalScore(
        SCORE_TYPE _type,
        bytes32 _totalScore
    ) external;

    function setCallerStatus(address _caller, bool _flag) external;

    function addNewScoreType(bytes memory _type) external returns (uint256);
   
}
