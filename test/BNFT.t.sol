// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Deposit.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Auction.sol";

contract DepositTest is Test {

    Deposit public depositInstance;
    BNFT public TestBNFTInstance;
    TNFT public TestTNFTInstance;
    Auction public auctionInstance;

    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        auctionInstance = new Auction();
        depositInstance = new Deposit(address(auctionInstance));
        TestBNFTInstance = BNFT(address(depositInstance.BNFTInstance()));
        TestTNFTInstance = TNFT(address(depositInstance.TNFTInstance()));
        vm.stopPrank();
    }

    function testBNFTContractGetsInstantiatedCorrectly() public {
        assertEq(TestBNFTInstance.depositContractAddress(), address(depositInstance));
        assertEq(TestBNFTInstance.nftValue(), 2 ether);
        assertEq(TestBNFTInstance.owner(), address(owner));
    }

    function testBNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only deposit contract function");
        TestBNFTInstance.mint(address(alice));
    }

    function testBNFTCannotBeTransferred() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        depositInstance.deposit{value: 0.1 ether}();  
        vm.expectRevert("Err: token is SOUL BOUND");      
        TestBNFTInstance.transferFrom(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931, address(alice), 0);
    }
}