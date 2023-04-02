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
        AuctionManagerV2 auctionManagerV2Implementation = new AuctionManagerV2();

        vm.prank(owner);
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2(address(auctionManagerProxy));

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        auctionManagerV2Instance.initialize(address(nodeOperatorManagerInstance));

        assertEq(auctionManagerV2Instance.numberOfBids(), 1);
        assertEq(auctionManagerV2Instance.isUpgraded(), true);
    }
}