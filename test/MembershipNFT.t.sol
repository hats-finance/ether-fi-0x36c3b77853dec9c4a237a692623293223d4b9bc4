// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract MembershipNFTTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public ownerProof;

    function setUp() public {
        setUpTests();
        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        eETHInstance.approve(address(membershipManagerInstance), 1_000_000_000 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        eETHInstance.approve(address(membershipManagerInstance), 1_000_000_000 ether);
        vm.stopPrank();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);
    }

    function test_metadata() public {

        // only admin can update uri
        vm.expectRevert("Ownable: caller is not the owner");
        membershipNftInstance.setMetadataURI("badURI.com");
        vm.expectRevert("Ownable: caller is not the owner");
        membershipNftInstance.setContractMetadataURI("badURI2.com");

        vm.startPrank(owner);
        membershipNftInstance.setMetadataURI("http://ether-fi/{id}");
        assertEq(membershipNftInstance.uri(5), "http://ether-fi/{id}");

        membershipNftInstance.setContractMetadataURI("http://ether-fi/contract-metadata");
        assertEq(membershipNftInstance.contractURI(), "http://ether-fi/contract-metadata");

        vm.stopPrank();
    }

    function test_permissions() public {

        // only membership manager can update call
        vm.startPrank(alice);
        vm.expectRevert(MembershipNFT.OnlyMembershipManagerContract.selector);
        membershipNftInstance.mint(alice, 1);
        vm.expectRevert(MembershipNFT.OnlyMembershipManagerContract.selector);
        membershipNftInstance.burn(alice, 0, 1);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert(MembershipNFT.OnlyMembershipManagerContract.selector);
        membershipNftInstance.mint(alice, 1);
        vm.expectRevert(MembershipNFT.OnlyMembershipManagerContract.selector);
        membershipNftInstance.burn(alice, 0, 1);
        vm.stopPrank();

        // should succeed
        vm.startPrank(address(membershipManagerInstance));
        membershipNftInstance.mint(alice, 1);
        membershipNftInstance.burn(alice, 0, 1);
        vm.stopPrank();
    }
}
