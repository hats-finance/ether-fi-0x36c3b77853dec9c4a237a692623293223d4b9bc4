// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegulationsManager {
    function initialize() external;

    function confirmEligibility() external;

    function removeFromWhitelist(address _user) external;

    function resetWhitelist() external;

    function isEligible(uint32 _whitelistVersion, address _user) external view returns (bool);

    function whitelistVersion() external view returns (uint32);

}
