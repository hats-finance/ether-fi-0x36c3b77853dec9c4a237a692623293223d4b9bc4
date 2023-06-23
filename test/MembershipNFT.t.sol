// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TestSetup.sol";
import "forge-std/console2.sol";

contract MembershipNFTTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public ownerProof;

    event MintingPaused(bool isPaused);

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
        vm.expectRevert("Only admin function");
        membershipNftInstance.setMetadataURI("badURI.com");
        vm.expectRevert("Only admin function");
        membershipNftInstance.setContractMetadataURI("badURI2.com");

        vm.startPrank(alice);
        membershipNftInstance.setMetadataURI("http://ether-fi/{id}");
        assertEq(membershipNftInstance.uri(5), "http://ether-fi/{id}");

        membershipNftInstance.setContractMetadataURI("http://ether-fi/contract-metadata");
        assertEq(membershipNftInstance.contractURI(), "http://ether-fi/contract-metadata");

        vm.stopPrank();
    }

    function test_pauseMinting() public {

        // only owner can set pause status
        vm.startPrank(owner);
        vm.expectRevert("Only admin function");
        membershipNftInstance.setMintingPaused(true);
        vm.stopPrank();

        // mint a token
        vm.prank(address(membershipManagerInstance));
        membershipNftInstance.mint(alice, 1);

        // pause the minting
        vm.prank(alice);
        vm.expectEmit(false, false, false, true);
        emit MintingPaused(true);
        membershipNftInstance.setMintingPaused(true);
        assertEq(membershipNftInstance.mintingPaused(), true);

        // mint should fail
        vm.startPrank(address(membershipManagerInstance));
        vm.expectRevert(MembershipNFT.MintingIsPaused.selector);
        membershipNftInstance.mint(alice, 1);
        vm.stopPrank();

        // unpause
        vm.prank(alice);
        vm.expectEmit(false, false, false, true);
        emit MintingPaused(false);
        membershipNftInstance.setMintingPaused(false);
        assertEq(membershipNftInstance.mintingPaused(), false);

        // mint should succeed again
        vm.startPrank(address(membershipManagerInstance));
        membershipNftInstance.mint(alice, 1);


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
