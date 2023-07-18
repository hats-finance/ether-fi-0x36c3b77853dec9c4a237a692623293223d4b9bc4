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
            address implementation,
            bool isActive,
            string memory name
        ) = addressProviderInstance.contracts("AuctionManager");
        
        assertEq(version, 1);
        assertEq(lastModified, 20000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionInstance));
        assertEq(isActive, false);
        assertEq(name, "AuctionManager");
        assertEq(addressProviderInstance.numberOfContracts(), 1);
    }

    function test_UpdateContract() public {
        vm.startPrank(owner);
        vm.expectRevert("Contract doesn't exists");
        addressProviderInstance.updateContractImplementation(
            "AuctionManager",
            address(auctionInstance)
        );

        vm.warp(20000);
        addressProviderInstance.addContract(
            address(auctionManagerProxy),
            "AuctionManager"
        );
        vm.stopPrank();

        vm.expectRevert("Only owner function");
        vm.prank(alice);
        addressProviderInstance.updateContractImplementation(
            "AuctionManager",
            address(auctionInstance)
        );

        vm.startPrank(owner);
        vm.expectRevert("Implementation cannot be zero addr");
        addressProviderInstance.updateContractImplementation("AuctionManager", address(0));

        addressProviderInstance.deactivateContract("AuctionManager");

        vm.expectRevert("Contract deprecated");
        addressProviderInstance.updateContractImplementation(
            "AuctionManager",
            address(auctionInstance)
        );

        addressProviderInstance.reactivateContract("AuctionManager");

        AuctionManagerV2Test auctionManagerV2Implementation = new AuctionManagerV2Test();
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2Test(
            address(auctionManagerProxy)
        );

        vm.warp(2500000);
        addressProviderInstance.updateContractImplementation(
            "AuctionManager",
            address(auctionManagerV2Instance)
        );

        (
            uint256 version,
            uint256 lastModified,
            address proxy,
            address implementation,
            bool isDeprecated,
            string memory name
        ) = addressProviderInstance.contracts("AuctionManager");

        
        assertEq(version, 2);
        assertEq(lastModified, 2500000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionManagerV2Instance));
        assertEq(isDeprecated, false);
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

        (, , , , bool isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
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

        (, , , , bool isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
        assertEq(isDeprecated, true);

        addressProviderInstance.reactivateContract("AuctionManager");
        (, , , , isDeprecated, ) = addressProviderInstance.contracts("AuctionManager");
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
