// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/LPAPoints.sol";

contract LPAPointsTest is Test {

    LPAPoints pointsContract;
    address admin;
    address plebian;

    event PointsPurchased(address indexed buyer, uint256 amountWei);

    function setUp() public {
        admin = address(0x01234);
        plebian = address(0x4321);

        vm.prank(admin);
        pointsContract = new LPAPoints();
    }

    function test_purchasePoints() public {
        vm.deal(plebian, 1 ether);

        vm.startPrank(plebian);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.5 ether);
        pointsContract.purchasePoints{value: 0.5 ether}();
        assertEq(address(pointsContract).balance, 0.5 ether);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.3 ether);
        pointsContract.purchasePoints{value: 0.3 ether}();
        assertEq(address(pointsContract).balance, 0.8 ether);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.2 ether);
        pointsContract.purchasePoints{value: 0.2 ether}();
        assertEq(address(pointsContract).balance, 1.0 ether);

        vm.stopPrank();
    }

    function test_purchaseViaReceive() public {

        vm.deal(plebian, 1 ether);

        vm.startPrank(plebian);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.5 ether);
        (bool success, ) = address(pointsContract).call{value: 0.5 ether}("");
        assertTrue(success); // get rid of warnings :)
        assertEq(address(pointsContract).balance, 0.5 ether);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.3 ether);
        (success, ) = address(pointsContract).call{value: 0.3 ether}("");
        assertTrue(success);
        assertEq(address(pointsContract).balance, 0.8 ether);

        vm.expectEmit(true, false, false, true);
        emit PointsPurchased(plebian, 0.2 ether);
        (success, ) = address(pointsContract).call{value: 0.2 ether}("");
        assertTrue(success);
        assertEq(address(pointsContract).balance, 1.0 ether);

        vm.stopPrank();
    }

    function test_withdrawFunds() public {
        vm.deal(plebian, 1 ether);
        vm.startPrank(plebian);
        pointsContract.purchasePoints{value: 0.5 ether}();
        assertEq(address(pointsContract).balance, 0.5 ether);

        // should fail
        vm.expectRevert("Ownable: caller is not the owner");
        pointsContract.withdrawFunds(payable(plebian));
        vm.stopPrank();

        vm.startPrank(admin); 
        pointsContract.withdrawFunds(payable(admin));
        assertEq(admin.balance, 0.5 ether);
        assertEq(address(pointsContract).balance, 0 ether);
        vm.stopPrank();

    }

}
