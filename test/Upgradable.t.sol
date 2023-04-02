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

contract TNFTV2 is TNFT {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract EtherFiNodesManagerV2 is EtherFiNodesManager {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract ProtocolRevenueManagerV2 is ProtocolRevenueManager {
    function isUpgraded() public view returns(bool){
        return true;
    }
}

contract UpgradeTest is TestSetup {

    AuctionManagerV2 public auctionManagerV2Instance;
    BNFTV2 public BNFTV2Instance;
    TNFTV2 public TNFTV2Instance;
    EtherFiNodesManagerV2 public etherFiNodesManagerV2Instance;
    ProtocolRevenueManagerV2 public protocolRevenueManagerV2Instance;

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

    function test_CanUpgradeTNFT() public {
        assertEq(TNFTInstance.getImplementation(), address(TNFTImplementation));

        TNFTV2 TNFTV2Implementation = new TNFTV2();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        stakingManagerInstance.upgradeTNFT(address(TNFTV2Implementation));

        vm.prank(owner);
        stakingManagerInstance.upgradeTNFT(address(TNFTV2Implementation));

        TNFTV2Instance = TNFTV2(address(TNFTProxy));
        
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        TNFTV2Instance.initialize();

        assertEq(TNFTV2Instance.getImplementation(), address(TNFTV2Implementation));
        assertEq(TNFTV2Instance.isUpgraded(), true);
    }

    function test_CanUpgradeEtherFiNodesManager() public {
        assertEq(managerInstance.getImplementation(), address(managerImplementation));

        vm.prank(owner);
        managerInstance.setStakingRewardsSplit(uint64(100000), uint64(100000), uint64(400000), uint64(400000));

        EtherFiNodesManagerV2 managerV2Implementation = new EtherFiNodesManagerV2();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        managerInstance.upgradeTo(address(managerV2Implementation));

        vm.prank(owner);
        managerInstance.upgradeTo(address(managerV2Implementation));

        etherFiNodesManagerV2Instance = EtherFiNodesManagerV2(payable(address(etherFiNodeManagerProxy)));

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        etherFiNodesManagerV2Instance.initialize(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TNFTInstance),
            address(BNFTInstance),
            address(protocolRevenueManagerInstance)
        );

        assertEq(etherFiNodesManagerV2Instance.getImplementation(), address(managerV2Implementation));
        assertEq(etherFiNodesManagerV2Instance.isUpgraded(), true);

        // State is maintained
        (uint64 treasury, uint64 nodeOperator, uint64 tnft, uint64 bnft) = etherFiNodesManagerV2Instance.stakingRewardsSplit();
        assertEq(treasury, 100000);
        assertEq(nodeOperator, 100000);
        assertEq(tnft, 400000);
        assertEq(bnft, 400000);
    }

    function test_CanUpgradeProtocolRevenueManager() public {
        assertEq(protocolRevenueManagerInstance.getImplementation(), address(protocolRevenueManagerImplementation));

        vm.prank(owner);
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(uint128(60));

        ProtocolRevenueManagerV2 protocolRevenueManagerV2Implementation = new ProtocolRevenueManagerV2();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(alice);
        protocolRevenueManagerInstance.upgradeTo(address(protocolRevenueManagerV2Implementation));

        vm.prank(owner);
        protocolRevenueManagerInstance.upgradeTo(address(protocolRevenueManagerV2Implementation));

        protocolRevenueManagerV2Instance = ProtocolRevenueManagerV2(payable(address(protocolRevenueManagerProxy)));

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        protocolRevenueManagerInstance.initialize();

        assertEq(protocolRevenueManagerV2Instance.getImplementation(), address(protocolRevenueManagerV2Implementation));
        assertEq(protocolRevenueManagerV2Instance.isUpgraded(), true);

        // State is maintained
        assertEq(protocolRevenueManagerV2Instance.vestedAuctionFeeSplitForStakers(), 60);
    }
}