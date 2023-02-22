// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IEETH {
    function mint(address _account, uint256 _amount) external;
    function quietMint(address _account, uint256 _amount) external;
    function mintBatch(address[34] memory _accounts, uint256[34] memory _amounts, uint256 _totalAmount) external;
    function mintBatch(address[18] memory _accounts, uint256[18] memory _amounts, uint256 _totalAmount) external;
    function burn(address _account, uint256 _amount) external;
}
