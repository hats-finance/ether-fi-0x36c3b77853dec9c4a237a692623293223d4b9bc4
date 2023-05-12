// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMEETH {
    function wrapEEth(uint256 _amount) external;
    function wrapEth(address _account, bytes32[] calldata _merkleProof) external payable;
    function wrapEthForEap(address _account, uint40 _points, bytes32[] calldata _merkleProof) external payable;
    function unwrapForEEth(uint256 _amount) external;
    function unwrapForEth(uint256 _amount) external;

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function transfer(address _recipient, uint256 _amount) external returns (bool);

    function totalSupply() external view returns (uint256);
    function totalShares() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);
    function pointsOf(address _account) external view returns (uint40);
    function tierOf(address _user) external view returns (uint8);

    function recentTierSnapshotTimestamp() external view returns (uint256);
    function pointsSnapshotTimeOf(address _account) external view returns (uint32);
    function getPointsEarningsDuringLastMembershipPeriod(address _account) external view returns (uint40);

    function tierForPoints(uint40 _points) external view returns (uint8);
    function claimableTier(address _account) external view returns (uint8);
}
