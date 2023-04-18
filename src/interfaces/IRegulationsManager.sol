// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegulationsManager {
    function initialize() external;

    function confirmEligibility(bytes memory _isoCode, string memory _declarationHash) external;

    function removeFromWhitelist(address _user) external;

    function resetWhitelist() external;

    function isEligible(uint32 _declarationIteration, address _user) external view returns (bool);
    function userIsoCode(uint32 _declarationIteration, address user) external view returns (bytes memory);
    function declarationHash(uint32 _declarationIteration, address user) external view returns (string memory);

    function declarationIteration() external view returns (uint32);

}
