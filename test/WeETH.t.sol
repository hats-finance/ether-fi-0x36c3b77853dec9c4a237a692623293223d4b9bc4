// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract WeETHTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public gregProof;

    function setUp() public {
        setUpTests();
        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        bobProof = merkle.getProof(whiteListedAddresses, 4);
        gregProof = merkle.getProof(whiteListedAddresses, 8);
    }

    function test_WrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("weETH: can't wrap zero eETH");
        weEthInstance.wrap(0);
    }

    function test_WrapWorksCorrectly() public {

        // Total pooled ether = 10
        vm.deal(address(liquidityPoolInstance), 10 ether);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        // Total pooled ether = 20
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 20 ether);
        assertEq(eETHInstance.totalSupply(), 20 ether);

        // ALice is first so get 100% of shares
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        startHoax(alice);

        //Approve the wrapped eth contract to spend 100 eEth
        eETHInstance.approve(address(weEthInstance), 100 ether);
        weEthInstance.wrap(5 ether);

        assertEq(eETHInstance.shares(alice), 7.5 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 2.5 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);
        assertEq(weEthInstance.balanceOf(alice), 2.5 ether);
    }

    function test_UnWrapEETHFailsIfZeroAmount() public {
        vm.expectRevert("Cannot wrap a zero amount");
        weEthInstance.unwrap(0);
    }

    function test_UnWrapWorksCorrectly() public {
        // Total pooled ether = 10
        vm.deal(address(liquidityPoolInstance), 10 ether);
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        // Total pooled ether = 20
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 20 ether);
        assertEq(eETHInstance.totalSupply(), 20 ether);

        // ALice is first so get 100% of shares
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        startHoax(alice);

        //Approve the wrapped eth contract to spend 100 eEth
        eETHInstance.approve(address(weEthInstance), 100 ether);
        weEthInstance.wrap(5 ether);

        assertEq(eETHInstance.shares(alice), 7.5 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 2.5 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);
        assertEq(weEthInstance.balanceOf(alice), 2.5 ether);

        weEthInstance.unwrap(2.5 ether);

        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 0  ether);
        assertEq(eETHInstance.totalShares(), 10 ether);
        assertEq(weEthInstance.balanceOf(alice), 0 ether);
    }

    function test_MultipleDepositsAndFunctionalityWorksCorrectly() public {
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 10 ether}(alice, aliceProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 10 ether);
        assertEq(eETHInstance.totalSupply(), 10 ether);

        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 10 ether);

        //----------------------------------------------------------------------------------------------------------

        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 5 ether}(bob, bobProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 15 ether);
        assertEq(eETHInstance.totalSupply(), 15 ether);

        assertEq(eETHInstance.shares(bob), 5 ether);
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 15 ether);

        //----------------------------------------------------------------------------------------------------------

        startHoax(greg);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 35 ether}(greg, gregProof);
        vm.stopPrank();

        assertEq(liquidityPoolInstance.getTotalPooledEther(), 50 ether);
        assertEq(eETHInstance.totalSupply(), 50 ether);

        assertEq(eETHInstance.shares(greg), 35 ether);
        assertEq(eETHInstance.shares(bob), 5 ether);
        assertEq(eETHInstance.shares(alice), 10 ether);
        assertEq(eETHInstance.totalShares(), 50 ether);

        //----------------------------------------------------------------------------------------------------------

        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingRewards(10 ether);
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(liquidityPoolInstance).call{value: 10 ether}("");
        require(sent, "Failed to send Ether");        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 60 ether);
        assertEq(eETHInstance.balanceOf(greg), 42 ether);

        //----------------------------------------------------------------------------------------------------------

        startHoax(alice);
        eETHInstance.approve(address(weEthInstance), 500 ether);
        weEthInstance.wrap(10 ether);
        assertEq(eETHInstance.shares(alice), 1.666666666666666667 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 8.333333333333333333 ether);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);

        //Not sure what happens to the 0.000000000000000001 ether
        assertEq(eETHInstance.balanceOf(address(weEthInstance)), 9.999999999999999999 ether);
        assertEq(weEthInstance.balanceOf(alice), 8.333333333333333333 ether);
        vm.stopPrank();

        //----------------------------------------------------------------------------------------------------------

        vm.startPrank(owner);
        liquidityPoolInstance.setAccruedStakingRewards(50 ether);
        vm.stopPrank();

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (sent, ) = address(liquidityPoolInstance).call{value: 50 ether}("");
        require(sent, "Failed to send Ether");        
        assertEq(liquidityPoolInstance.getTotalPooledEther(), 110 ether);
        assertEq(eETHInstance.balanceOf(alice), 3.666666666666666667 ether);

        //----------------------------------------------------------------------------------------------------------

        startHoax(alice);
        weEthInstance.unwrap(6 ether);
        assertEq(eETHInstance.balanceOf(alice), 16.866666666666666667 ether);
        assertEq(eETHInstance.shares(alice), 7.666666666666666667 ether);
        assertEq(eETHInstance.balanceOf(address(weEthInstance)), 5.133333333333333332 ether);
        assertEq(eETHInstance.shares(address(weEthInstance)), 2.333333333333333333 ether);
        assertEq(weEthInstance.balanceOf(alice), 2.333333333333333333 ether);
    }

    function test_UnwrappingWithRewards() public {
        // Alice deposits into LP
        startHoax(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 2 ether}(alice, aliceProof);
        assertEq(eETHInstance.balanceOf(alice), 2 ether);
        vm.stopPrank();

        // Bob deposits into LP
        startHoax(bob);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        liquidityPoolInstance.deposit{value: 1 ether}(bob, bobProof);
        assertEq(eETHInstance.balanceOf(bob), 1 ether);
        vm.stopPrank();

        //Bob chooses to wrap his eETH into weETH
        vm.startPrank(bob);
        eETHInstance.approve(address(weEthInstance), 1 ether);
        weEthInstance.wrap(1 ether);
        assertEq(eETHInstance.balanceOf(bob), 0 ether);
        assertEq(weEthInstance.balanceOf(bob), 1 ether);

        // Rewards enter LP
        vm.deal(address(liquidityPoolInstance), 4 ether);
        assertEq(address(liquidityPoolInstance).balance, 4 ether);

        // Alice now has 2.666666666666666666 ether
        // Bob should still have 1 weETH because it doesn't rebase
        assertEq(eETHInstance.balanceOf(alice), 2.666666666666666666 ether);
        assertEq(weEthInstance.balanceOf(bob), 1 ether);

        // Bob unwraps his weETH and should get his principal + rewards
        // Bob should get 1.333333333333333333 ether

        /// @notice not sure where the 0.000000000000000001 ether goes to. Possible that it gets rounded down on conversion
        weEthInstance.unwrap(1 ether);
        assertEq(eETHInstance.balanceOf(bob), 1.333333333333333332 ether);
    }
}
