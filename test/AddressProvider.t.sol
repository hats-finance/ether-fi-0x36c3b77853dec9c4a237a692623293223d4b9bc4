// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract AddressProviderTest is TestSetup {

    function setUp() public {
        setUpTests();
    }

    function test_ContractInstantiatedCorrectly() public {
        assertEq(addressProviderInstance.owner(), address(owner));
        assertEq(addressProviderInstance.numberOfContracts(), 0);
    }

    function test_AddNewContract() public {
        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            "AuctionManager"
        );

        vm.startPrank(owner);
        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            "AuctionManager"
        );

        (
            uint256 version,
            uint256 lastModified,
            address proxy,
            bool isActive,
            string memory name
        ) = addressProviderInstance.contracts("AuctionManager");
        
        assertEq(version, 1);
        assertEq(lastModified, 20000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(isActive, false);
        assertEq(name, "AuctionManager");
        assertEq(addressProviderInstance.numberOfContracts(), 1);
    }

    function test_DeactivateContract() public {
        vm.prank(owner);
        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            "Auction Manager"
        );

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.deactivateContract("AuctionManager");

        vm.startPrank(owner);
        addressProviderInstance.deactivateContract("AuctionManager");

        (, , , bool isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
        assertEq(isDeprecated, true);

        vm.expectRevert("Contract already deprecated");
        addressProviderInstance.deactivateContract("AuctionManager");
    }

    function test_ReactivateContract() public {
        vm.prank(owner);
        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            "Auction Manager"
        );

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.reactivateContract("AuctionManager");

        vm.startPrank(owner);
        vm.expectRevert("Contract already active");
        addressProviderInstance.reactivateContract("AuctionManager");

        addressProviderInstance.deactivateContract("AuctionManager");

        (, , , bool isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
        assertEq(isDeprecated, true);

        addressProviderInstance.reactivateContract("AuctionManager");
        (, , , isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
        assertEq(isDeprecated, false);
    }

    function test_SetOwner() public {
        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.setOwner(address(alice));

        vm.startPrank(owner);
        vm.expectRevert("Cannot be zero addr");
        addressProviderInstance.setOwner(address(0));

        assertEq(addressProviderInstance.owner(), address(owner));

        addressProviderInstance.setOwner(address(alice));
        assertEq(addressProviderInstance.owner(), address(alice));
    }
}
