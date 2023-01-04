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
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        depositInstance = new Deposit();
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testTNFTContractGetsInstantiatedCorrectly() public {
        assertEq(TestTNFTInstance.depositContractAddress(), address(depositInstance));
        assertEq(TestTNFTInstance.nftValue(), 30 ether);
        assertEq(TestTNFTInstance.owner(), address(owner));
    }

    function testTNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only deposit contract function");
        TestTNFTInstance.mint(address(alice));
    }
}