pragma solidity 0.8.13;

interface IWETH {

    function wrap(uint256 _eETHAmount) external returns (uint256);
    function unwrap(uint256 _weETHAmount) external returns (uint256);

    function getWeETHByeETH(uint256 _eETHAmount) external view returns (uint256);
    function getEETHByWeETH(uint256 _weETHAmount) external view returns (uint256);
    function getImplementation() external view returns (address);
}
