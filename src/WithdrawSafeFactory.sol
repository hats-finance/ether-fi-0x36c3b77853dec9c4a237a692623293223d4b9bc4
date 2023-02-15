// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./withdrawSafe.sol";

contract WithdrawSafeFactory {
    address public immutable implementationContract;

    constructor() {
        implementationContract = address(new WithdrawSafe());
    }

    function createWithdrawalSafe() external returns (address) {
        address clone = Clones.clone(implementationContract);
        WithdrawSafe(payable(clone)).initialize();
        return clone;
    }
}
