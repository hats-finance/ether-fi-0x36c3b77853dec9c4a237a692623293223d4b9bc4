// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegulationsManager {
    function initialize() external;

    function confirmEligibility(bytes32 _declarationHash) external;

    function removeFromWhitelist(address _user) external;

    function resetWhitelist() external;

    function isEligible(uint32 _whitelistVersion, address _user) external view returns (bool);
    function declarationHash(uint32 _whitelistVersion, address user) external view returns (bytes32);

    function whitelistVersion() external view returns (uint32);

}
