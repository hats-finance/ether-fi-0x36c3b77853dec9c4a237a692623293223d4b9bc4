// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IBNFT {
    function mint(address _reciever, uint256 _validatorId, uint256 _numberOfValidators) external;
}
