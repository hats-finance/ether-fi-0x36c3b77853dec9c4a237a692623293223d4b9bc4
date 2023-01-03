// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";

contract DepositTest is Test {

    Deposit public depositInstance;

    address owner = vm.addr(1);
    address staker = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositInstance = new Deposit();
        vm.stopPrank();
    }

}