// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IRegulationsManager {
    function initialize() external;

    function confirmEligibility(bytes memory _isoCode) external;

}
