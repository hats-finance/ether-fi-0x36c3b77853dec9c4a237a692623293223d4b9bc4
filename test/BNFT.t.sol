// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract BNFTTest is TestSetup {
   
   function setUp() public {
        setUpTests();
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
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIds
        );

        startHoax(alice);
        stakingManagerInstance.registerValidator(bidIds[0], test_data);
        vm.stopPrank();

        assertEq(BNFTInstance.ownerOf(1), alice);
        assertEq(BNFTInstance.balanceOf(alice), 1);
    }

    function test_BNFTMintsFailsIfNotCorrectCaller() public {
        vm.startPrank(alice);
        vm.expectRevert("Only staking manager contract");
        BNFTInstance.mint(address(alice), 1);
    }

    function test_BNFTCannotBeTransferred() public {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);

        auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        uint256[] memory bidIdArray = new uint256[](1);
        bidIdArray[0] = 1;

        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(
            bidIdArray
        );

        vm.expectRevert("Err: token is SOUL BOUND");
        BNFTInstance.transferFrom(
            0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
            address(alice),
            0
        );
    }
}
