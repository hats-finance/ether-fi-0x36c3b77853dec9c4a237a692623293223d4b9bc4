// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";

contract DepositTest is Test {

    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;

    address owner = vm.addr(1);
    address staker = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositInstance = new Deposit();
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testDepositCreatesNFTs() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.2 ether}();
        assertEq(address(depositInstance).balance, 0.2 ether);
    }

    
}