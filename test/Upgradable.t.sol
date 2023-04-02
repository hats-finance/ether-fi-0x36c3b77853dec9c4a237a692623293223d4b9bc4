// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract AuctionManagerV2 is AuctionManager {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract BNFTV2 is BNFT {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract UpgradeTest is TestSetup {

    AuctionManagerV2 public auctionManagerV2Instance;
    BNFTV2 public BNFTV2Instance;

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
        assertEq(auctionInstance.getImplementation(), address(auctionImplementation));

        AuctionManagerV2 auctionManagerV2Implementation = new AuctionManagerV2();

        vm.prank(owner);
        auctionInstance.upgradeTo(address(auctionManagerV2Implementation));

        auctionManagerV2Instance = AuctionManagerV2(address(auctionManagerProxy));

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        auctionManagerV2Instance.initialize(address(nodeOperatorManagerInstance));

        assertEq(auctionManagerV2Instance.getImplementation(), address(auctionManagerV2Implementation));

        // Check that state is maintained
        assertEq(auctionManagerV2Instance.numberOfActiveBids(), 1);
        assertEq(auctionManagerV2Instance.isUpgraded(), true);
    }

    function test_CanUpgradeBNFT() public {
        assertEq(BNFTInstance.getImplementation(), address(BNFTImplementation));

        BNFTV2 BNFTV2Implementation = new BNFTV2();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        stakingManagerInstance.upgradeBNFT(address(BNFTV2Implementation));

        vm.prank(owner);
        stakingManagerInstance.upgradeBNFT(address(BNFTV2Implementation));

        BNFTV2Instance = BNFTV2(address(BNFTProxy));
        
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        BNFTV2Instance.initialize();

        assertEq(BNFTV2Instance.getImplementation(), address(BNFTV2Implementation));
        assertEq(BNFTV2Instance.isUpgraded(), true);
    }
}