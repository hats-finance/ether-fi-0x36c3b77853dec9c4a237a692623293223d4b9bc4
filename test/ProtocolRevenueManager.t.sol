// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestSetup.sol";

contract ProtocolRevenueManagerTest is TestSetup {
        
    bytes32[] public proof;
    bytes32[] public aliceProof;
    
    function setUp() public {
        setUpTests();

        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        protocolRevenueManagerImplementation.initialize();

        assertEq(protocolRevenueManagerInstance.globalRevenueIndex(), 1);
        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            50
        );
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            168
        );
        assertEq(
            address(protocolRevenueManagerInstance.etherFiNodesManager()),
            address(managerInstance)
        );
        assertEq(
            address(protocolRevenueManagerInstance.auctionManager()),
            address(auctionInstance)
        );

        vm.startPrank(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.registerNodeOperator(_ipfsHash, 5);
        vm.stopPrank();

        vm.prank(alice);
        nodeOperatorManagerInstance.registerNodeOperator(
            _ipfsHash,
            5
        );
    }

    function test_changeAuctionRewardParams() public {
        vm.expectRevert("Caller is not the admin");
        protocolRevenueManagerInstance.setAuctionRewardVestingPeriod(1);
        vm.expectRevert("Caller is not the admin");
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(10);

        vm.startPrank(alice);
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            168
        );
        protocolRevenueManagerInstance.setAuctionRewardVestingPeriod(1);
        assertEq(
            protocolRevenueManagerInstance
                .auctionFeeVestingPeriodForStakersInDays(),
            1
        );

        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            50
        );
        protocolRevenueManagerInstance.setAuctionRewardSplitForStakers(10);
        assertEq(
            protocolRevenueManagerInstance.vestedAuctionFeeSplitForStakers(),
            10
        );
    }

    function test_Receive() public {
        // TODO(Dave)
        // ProtocolRevenueManager is being removed
    }

    function test_GetAccruedAuctionRevenueRewards() public {
        // TODO(Dave)
        // ProtocolRevenueManager is being removed
    }

    function test_AddAuctionRevenueWorksAndFailsCorrectly() public {
        // TODO(Dave)
        // ProtocolRevenueManager is being removed
    }

    function test_modifiers() public {
        hoax(alice);
        vm.expectRevert("Only auction manager function");
        protocolRevenueManagerInstance.addAuctionRevenue(0);

        vm.expectRevert("Only etherFiNodesManager function");
        protocolRevenueManagerInstance.distributeAuctionRevenue(0);

        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setAuctionManagerAddress(alice);

        vm.expectRevert("Ownable: caller is not the owner");
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(alice);
    }
}
