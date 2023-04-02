// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract AuctionManagerV2 is AuctionManager {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract UpgradeTest is TestSetup {

    UUPSProxy public auctionManagerV2Proxy;
    AuctionManagerV2 public auctionManagerV2Instance;

    function setUp() public {
        setUpTests();
    }

    function test_CanUpgradeAuctionManager() public {

        bytes32[] memory proof = merkle.getProof(whiteListedAddresses, 0);
        vm.prank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(
            proof,
            _ipfsHash,
            5
        );

        assertEq(auctionInstance.numberOfActiveBids(), 0);

        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        uint256[] memory bidIds = auctionInstance.createBid{value: 0.1 ether}(1, 0.1 ether);

        assertEq(auctionInstance.numberOfActiveBids(), 1);

        AuctionManagerV2 auctionManagerV2Implementation = new AuctionManagerV2();

        vm.prank(owner);
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2(address(auctionManagerProxy));

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        auctionManagerV2Instance.initialize(address(nodeOperatorManagerInstance));

        // Check that state is maintained
        assertEq(auctionManagerV2Instance.numberOfActiveBids(), 1);
        assertEq(auctionManagerV2Instance.isUpgraded(), true);
    }
}