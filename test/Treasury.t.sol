// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "forge-std/Test.sol";

// import "../src/Treasury.sol";

// contract TreasuryTest is Test {

//     Treasury treasuryInstance;

//     address owner = vm.addr(1);
//     address alice = vm.addr(2);

//     function setUp() public {
//         vm.startPrank(owner);
//         treasuryInstance = new Treasury();
//         vm.stopPrank();
//     }

//     function testTreasuryCanReceiveFunds() public {
//         assertEq(address(treasuryInstance).balance, 0);
//         startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         (bool sent,) = address(treasuryInstance).call{value: 0.5 ether}("");
//         assertEq(address(treasuryInstance).balance, 0.5 ether);
//     }

//     function testWithdrawFailsIfNotOwner() public {
//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         (bool sent,) = address(treasuryInstance).call{value: 0.5 ether}("");

//         vm.prank(alice);
//         vm.expectRevert("Only owner function");
//         treasuryInstance.withdraw();
//     }

//     function testWithdrawWorks() public {
//         assertEq(address(treasuryInstance).balance, 0);

//         hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
//         (bool sent,) = address(treasuryInstance).call{value: 0.5 ether}("");
//         assertEq(address(treasuryInstance).balance, 0.5 ether);

//         vm.prank(owner);
//         treasuryInstance.withdraw();

//         assertEq(address(owner).balance, 0.5 ether);
//         assertEq(address(treasuryInstance).balance, 0);
//     }
// }
