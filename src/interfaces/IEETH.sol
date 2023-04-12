// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IEETH {
    function initialize(address _liquidityPool) external;

    function totalShares() external view returns (uint256);

    function shares(address _user) external view returns (uint256);
    function balanceOf(address _user) external view returns (uint256);

    function mintShares(address _user, uint256 _share) external;
    function burnShares(address _user, uint256 _share) external;

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function transfer(address _recipient, uint256 _amount) external returns (bool);

}
