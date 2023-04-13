// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract WethETHTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_WrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("wstETH: can't wrap zero stETH");
        weEthInstance.wrap(0);
    }

    function test_WrapWorksCorrectly() public {

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(liquidityPoolInstance).call{value: 100 ether}("");
        require(sent, "Failed to send Ether");

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(alice, 100);
        assertEq(eETHInstance.shares(alice), 100);

        vm.startPrank(alice);
        eETHInstance.approve(address(weEthInstance), 100);
        weEthInstance.wrap(50);
        assertEq(eETHInstance.shares(alice), 50);
        assertEq(eETHInstance.shares(address(weEthInstance)), 50);
        assertEq(weEthInstance.balanceOf(alice), 50);

        vm.stopPrank();
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (sent, ) = address(liquidityPoolInstance).call{value: 500 ether}("");
        require(sent, "Failed to send Ether");

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(bob, 200);
        assertEq(eETHInstance.shares(bob), 200);

        vm.startPrank(bob);
        eETHInstance.approve(address(weEthInstance), 200);
        weEthInstance.wrap(100);
        assertEq(eETHInstance.shares(bob), 150);
        assertEq(eETHInstance.shares(address(weEthInstance)), 100);
        assertEq(weEthInstance.balanceOf(bob), 50);
        vm.stopPrank();

        vm.prank(address(liquidityPoolInstance));
        eETHInstance.mintShares(dan, 500);
        assertEq(eETHInstance.shares(dan), 500);

        vm.startPrank(dan);
        eETHInstance.approve(address(weEthInstance), 500);
        weEthInstance.wrap(300);
        assertEq(eETHInstance.shares(dan), 100);
        assertEq(eETHInstance.shares(address(weEthInstance)), 500);
        assertEq(weEthInstance.balanceOf(dan), 400);
    }

    function test_UnWrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("Cannot wrap a zero amount");
        weEthInstance.unwrap(0);
    }

    function test_UnWrapWorksCorrectly() public {
    
    }
}
