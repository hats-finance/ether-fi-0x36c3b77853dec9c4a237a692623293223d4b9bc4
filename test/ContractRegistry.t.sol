// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract AuctionManagerV2Test is AuctionManager {
    function isUpgraded() public pure returns (bool) {
        return true;
    }
}

contract ContractRegistryTest is TestSetup {
    AuctionManagerV2Test public auctionManagerV2Instance;

    function setUp() public {
        setUpTests();
    }

    function test_ContractInstantiatedCorrectly() public {
        assertEq(contractRegistryInstance.admin(), address(owner));
        assertEq(contractRegistryInstance.numberOfContracts(), 0);
    }

    function test_AddNewContract() public {
        vm.expectRevert("Only admin function");
        vm.prank(alice);
        contractRegistryInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        vm.startPrank(owner);
        vm.expectRevert("Implementation cannot be zero addr");
        contractRegistryInstance.addContract(
            address(0),
            address(0),
            "Auction Manager"
        );

        vm.warp(20000);
        contractRegistryInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        (
            uint256 version,
            uint256 lastModified,
            address proxy,
            address implementation,
            bool isActive,
            string memory name
        ) = contractRegistryInstance.contracts(0);

        assertEq(version, 1);
        assertEq(lastModified, 20000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionInstance));
        assertEq(isActive, true);
        assertEq(name, "Auction Manager");
        assertEq(contractRegistryInstance.nameToId("Auction Manager"), 0);
        assertEq(contractRegistryInstance.numberOfContracts(), 1);
    }

    function test_UpdateContract() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid contract ID");
        contractRegistryInstance.updateContractImplementation(
            1,
            address(auctionInstance)
        );

        vm.warp(20000);
        contractRegistryInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );
        vm.stopPrank();

        vm.expectRevert("Only admin function");
        vm.prank(alice);
        contractRegistryInstance.updateContractImplementation(
            0,
            address(auctionInstance)
        );

        vm.startPrank(owner);
        vm.expectRevert("Implementation cannot be zero addr");
        contractRegistryInstance.updateContractImplementation(0, address(0));

        contractRegistryInstance.discontinueContract(0);

        vm.expectRevert("Contract discontinued");
        contractRegistryInstance.updateContractImplementation(
            0,
            address(auctionInstance)
        );

        contractRegistryInstance.reviveContract(0);

        AuctionManagerV2Test auctionManagerV2Implementation = new AuctionManagerV2Test();
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2Test(
            address(auctionManagerProxy)
        );

        vm.warp(2500000);
        contractRegistryInstance.updateContractImplementation(
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
        ) = contractRegistryInstance.contracts(0);

        assertEq(version, 2);
        assertEq(lastModified, 2500000);
        assertEq(proxy, address(auctionManagerProxy));
        assertEq(implementation, address(auctionManagerV2Instance));
        assertEq(isActive, true);
        assertEq(name, "Auction Manager");
        assertEq(contractRegistryInstance.numberOfContracts(), 1);
    }

    function test_DiscontinueContract() public {
        vm.prank(owner);
        vm.warp(20000);
        contractRegistryInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        vm.expectRevert("Only admin function");
        vm.prank(alice);
        contractRegistryInstance.discontinueContract(0);

        vm.startPrank(owner);
        contractRegistryInstance.discontinueContract(0);

        (, , , , bool isActive, ) = contractRegistryInstance.contracts(0);
        assertEq(isActive, false);

        vm.expectRevert("Contract already discontinued");
        contractRegistryInstance.discontinueContract(0);
    }

    function test_ReviveContract() public {
        vm.prank(owner);
        vm.warp(20000);
        contractRegistryInstance.addContract(
            address(auctionManagerProxy),
            address(auctionInstance),
            "Auction Manager"
        );

        vm.expectRevert("Only admin function");
        vm.prank(alice);
        contractRegistryInstance.reviveContract(0);

        vm.startPrank(owner);
        vm.expectRevert("Contract already active");
        contractRegistryInstance.reviveContract(0);

        contractRegistryInstance.discontinueContract(0);

        (, , , , bool isActive, ) = contractRegistryInstance.contracts(0);
        assertEq(isActive, false);

        contractRegistryInstance.reviveContract(0);
        (, , , , isActive, ) = contractRegistryInstance.contracts(0);
        assertEq(isActive, true);
    }

    function test_SetAdmin() public {
        vm.expectRevert("Only admin function");
        vm.prank(alice);
        contractRegistryInstance.setAdmin(address(alice));

        vm.startPrank(owner);
        vm.expectRevert("Cannot be zero addr");
        contractRegistryInstance.setAdmin(address(0));

        assertEq(contractRegistryInstance.admin(), address(owner));

        contractRegistryInstance.setAdmin(address(alice));
        assertEq(contractRegistryInstance.admin(), address(alice));
    }
}
