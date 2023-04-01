// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract TnftTest is TestSetup {

    function setUp() public {
        setUpTests();

        assertEq(TestTNFTInstance.stakingManagerContractAddress(), address(stakingManagerInstance));
    }

    function test_TNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only staking mananger contract function");
        TestTNFTInstance.mint(address(alice), 1);
    }

    function test_Mint() public {
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );
        uint256[] memory bidIds = auctionInstance.createBid{value: 1 ether}(
            1,
            1 ether
        );
        vm.stopPrank();

        hoax(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 0.032 ether}(
            bidIds
        );

        startHoax(alice);
        stakingManagerInstance.registerValidator(bidIds[0], test_data);
        vm.stopPrank();

        assertEq(TestTNFTInstance.ownerOf(1), alice);
        assertEq(TestTNFTInstance.balanceOf(alice), 1);
    }
}
