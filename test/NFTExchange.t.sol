// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract NFTExchangeTest is TestSetup {

    bytes32[] public aliceProof;
    bytes32[] public ownerProof;
    bytes32[] public emptyProof;

    function setUp() public {
        setUpTests();

        vm.startPrank(alice);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        eETHInstance.approve(address(membershipManagerInstance), 1_000_000_000 ether);
        vm.stopPrank();

        aliceProof = merkle.getProof(whiteListedAddresses, 3);
        ownerProof = merkle.getProof(whiteListedAddresses, 10);

        vm.startPrank(owner);
        regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
        vm.stopPrank();
    }

    function test_trade() public {
        // Alice has staked 32 ETH and is holding 1 pair of {B, T}-NFTs
        uint256 tNftTokenId = _alice_stake();
 
        // Owner mints a membership NFT holding 30 ETH
        vm.deal(owner, 30 ether);
        vm.startPrank(owner);
        uint256 membershipNftTokenId = membershipManagerInstance.wrapEth{value: 30 ether}(30 ether, 0, ownerProof);

        // Owner prepares for the NFT; setting its (loyalty, tier) points
        uint256 aliceEapPoints = 100000;
        (uint40 loyaltyPoints, uint40 tierPoints) = membershipManagerInstance.convertEapPoints(aliceEapPoints, 30 ether);
        membershipManagerInstance.setPoints(membershipNftTokenId, loyaltyPoints, tierPoints);

        assertEq(membershipNftInstance.loyaltyPointsOf(membershipNftTokenId), loyaltyPoints);
        assertEq(membershipNftInstance.tierPointsOf(membershipNftTokenId), tierPoints);

        // Owner approves the NFTExchange to transfer the membership NFT
        membershipNftInstance.setApprovalForAll(address(nftExchangeInstance), true);

        // Owner lists it for sale
        uint256[] memory mNftTokenIds = new uint256[](1);
        address[] memory reservedBuyers = new address[](1);
        mNftTokenIds[0] = membershipNftTokenId;
        reservedBuyers[0] = alice;
        nftExchangeInstance.listForSale(mNftTokenIds, reservedBuyers);
        vm.stopPrank();

        uint256[] memory tNftTokenIds = new uint256[](1);
        tNftTokenIds[0] = tNftTokenId;

        // Fail: Bob is not the reserved buyer
        vm.startPrank(bob);
        vm.expectRevert("You are not the reserved buyer");
        nftExchangeInstance.buy(tNftTokenIds, mNftTokenIds);
        vm.stopPrank();

        // Success: Alice buys the membership NFT
        vm.startPrank(alice);
        TNFTInstance.setApprovalForAll(address(nftExchangeInstance), true);
        nftExchangeInstance.buy(tNftTokenIds, mNftTokenIds);

        // Fail: Already Sold
        vm.expectRevert("Token is not currently listed for sale");
        nftExchangeInstance.buy(tNftTokenIds, mNftTokenIds);
        vm.stopPrank();

        vm.startPrank(owner);
        // Fail: Already Sold
        vm.expectRevert("Token is not currently listed for sale");
        nftExchangeInstance.delist(mNftTokenIds);
        vm.stopPrank();
    }

    function test_delist() public {
        // Alice has staked 32 ETH and is holding 1 pair of {B, T}-NFTs
        uint256 tNftTokenId = _alice_stake();
 
        // Owner mints a membership NFT holding 30 ETH
        vm.deal(owner, 30 ether);
        vm.startPrank(owner);
        uint256 membershipNftTokenId = membershipManagerInstance.wrapEth{value: 30 ether}(30 ether, 0, ownerProof);

        // Owner prepares for the NFT; setting its (loyalty, tier) points
        uint256 aliceEapPoints = 100000;
        (uint40 loyaltyPoints, uint40 tierPoints) = membershipManagerInstance.convertEapPoints(aliceEapPoints, 30 ether);
        membershipManagerInstance.setPoints(membershipNftTokenId, loyaltyPoints, tierPoints);

        assertEq(membershipNftInstance.loyaltyPointsOf(membershipNftTokenId), loyaltyPoints);
        assertEq(membershipNftInstance.tierPointsOf(membershipNftTokenId), tierPoints);

        // Owner approves the NFTExchange to transfer the membership NFT
        membershipNftInstance.setApprovalForAll(address(nftExchangeInstance), true);

        // Owner lists it for sale
        uint256[] memory mNftTokenIds = new uint256[](1);
        address[] memory reservedBuyers = new address[](1);
        mNftTokenIds[0] = membershipNftTokenId;
        reservedBuyers[0] = alice;
        nftExchangeInstance.listForSale(mNftTokenIds, reservedBuyers);
        vm.stopPrank();

        uint256[] memory tNftTokenIds = new uint256[](1);
        tNftTokenIds[0] = tNftTokenId;

        vm.startPrank(owner);
        nftExchangeInstance.delist(mNftTokenIds);
        vm.stopPrank();

        // Fail: Delisted
        vm.expectRevert("Token is not currently listed for sale");
        nftExchangeInstance.buy(tNftTokenIds, mNftTokenIds);
        vm.stopPrank();
    }

    function _alice_stake() internal returns (uint256) {
        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(_ipfsHash, 5);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidId1 = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        vm.deal(alice, 32 ether);
        vm.startPrank(alice);
        stakingManagerInstance.batchDepositWithBidIds{value: 32 ether}(bidId1, proof);

        address etherFiNode = managerInstance.etherfiNodeAddress(1);
        bytes32 root = depGen.generateDepositRoot(
            hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
            hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
            managerInstance.generateWithdrawalCredentials(etherFiNode),
            32 ether
        );

        IStakingManager.DepositData[] memory depositDataArray = new IStakingManager.DepositData[](1);
        IStakingManager.DepositData memory depositData = IStakingManager
            .DepositData({
                publicKey: hex"8f9c0aab19ee7586d3d470f132842396af606947a0589382483308fdffdaf544078c3be24210677a9c471ce70b3b4c2c",
                signature: hex"877bee8d83cac8bf46c89ce50215da0b5e370d282bb6c8599aabdbc780c33833687df5e1f5b5c2de8a6cd20b6572c8b0130b1744310a998e1079e3286ff03e18e4f94de8cdebecf3aaac3277b742adb8b0eea074e619c20d13a1dda6cba6e3df",
                depositDataRoot: root,
                ipfsHashForEncryptedValidatorKey: "test_ipfs"
            });

        depositDataArray[0] = depositData;

        stakingManagerInstance.batchRegisterValidators(zeroRoot, bidId1, alice, alice, depositDataArray);
        assertEq(BNFTInstance.ownerOf(bidId1[0]), alice);
        assertEq(TNFTInstance.ownerOf(bidId1[0]), alice);

        vm.stopPrank();

        return bidId1[0];
    }


}
