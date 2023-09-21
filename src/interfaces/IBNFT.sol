// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IBNFT {
    function initialize() external;
    function mint(address _receiver, uint256 _validatorId) external;
    function getImplementation() external view returns (address);
    function upgradeTo(address _newImplementation) external;
}
