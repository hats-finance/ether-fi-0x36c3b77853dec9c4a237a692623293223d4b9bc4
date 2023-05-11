// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMEETH {

    function wrapEth(address _account, bytes32[] calldata _merkleProof) external payable;
    function wrapEthForEap(address _account, uint40 _points, bytes32[] calldata _merkleProof) external payable;

    function totalSupply() external view returns (uint256);
    function totalShares() external view returns (uint256);

    function balanceOf(address _user) external view returns (uint256);
    function pointOf(address _account) external view returns (uint40);
    function pointsSnapshotTimeOf(address _account) external view returns (uint32);

    function tierForPoints(uint40 _points) external view returns (uint8);

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function transfer(address _recipient, uint256 _amount) external returns (bool);
}
