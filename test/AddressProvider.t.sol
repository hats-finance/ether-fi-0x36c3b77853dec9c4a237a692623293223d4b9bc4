// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract AuctionManagerV2Test is AuctionManager {
    function isUpgraded() public pure returns (bool) {
        return true;
    }
}

contract AddressProviderTest is TestSetup {
    AuctionManagerV2Test public auctionManagerV2Instance;

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
            address(auctionInstance),
            "AuctionManager"
        );

        vm.startPrank(owner);
        vm.expectRevert("Implementation cannot be zero addr");
        addressProviderInstance.addContract(
            address(0),
            address(0),
            "AuctionManager"
        );

        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "AuctionManager"
        );

        (
            uint256 version,
            uint256 lastModified,
            address proxy,
            address implementation,
            bool isActive,
            string memory name
        ) = addressProviderInstance.contracts(0);
        
        assertEq(version, 1);
        assertEq(lastModified, 20000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionInstance));
        assertEq(isActive, true);
        assertEq(name, "AuctionManager");
        assertEq(addressProviderInstance.nameToId("AuctionManager"), 0);
        assertEq(addressProviderInstance.numberOfContracts(), 1);
    }

    function test_UpdateContract() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid contract ID");
        addressProviderInstance.updateContractImplementation(
            1,
            address(auctionInstance)
        );

        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "AuctionManager"
        );
        vm.stopPrank();

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.updateContractImplementation(
            0,
            address(auctionInstance)
        );

        vm.startPrank(owner);
        vm.expectRevert("Implementation cannot be zero addr");
        addressProviderInstance.updateContractImplementation(0, address(0));

        addressProviderInstance.deactivateContract(0);

        vm.expectRevert("Contract discontinued");
        addressProviderInstance.updateContractImplementation(
            0,
            address(auctionInstance)
        );

        addressProviderInstance.reactivateContract(0);

        AuctionManagerV2Test auctionManagerV2Implementation = new AuctionManagerV2Test();
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2Test(
            address(auctionManagerProxy)
        );

        vm.warp(2500000);
        addressProviderInstance.updateContractImplementation(
            0,
            address(auctionManagerV2Instance)
        );

        (
            uint256 version,
            uint256 lastModified,
            address proxy,
            address implementation,
            bool isActive,
            string memory name
        ) = addressProviderInstance.contracts(0);

        
        assertEq(version, 2);
        assertEq(lastModified, 2500000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionManagerV2Instance));
        assertEq(isActive, true);
        assertEq(name, "AuctionManager");
        assertEq(addressProviderInstance.numberOfContracts(), 1);
    }

    function test_DeactivateContract() public {
        vm.prank(owner);
        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.deactivateContract(0);

        vm.startPrank(owner);
        addressProviderInstance.deactivateContract(0);

        (, , , , bool isActive, ) = addressProviderInstance.contracts(0);
        assertEq(isActive, false);

        vm.expectRevert("Contract already discontinued");
        addressProviderInstance.deactivateContract(0);
    }

    function test_ReactivateContract() public {
        vm.prank(owner);
        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.reactivateContract(0);

        vm.startPrank(owner);
        vm.expectRevert("Contract already active");
        addressProviderInstance.reactivateContract(0);

        addressProviderInstance.deactivateContract(0);

        (, , , , bool isActive, ) = addressProviderInstance.contracts(0);
        assertEq(isActive, false);

        addressProviderInstance.reactivateContract(0);
        (, , , , isActive, ) = addressProviderInstance.contracts(0);
        assertEq(isActive, true);
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
