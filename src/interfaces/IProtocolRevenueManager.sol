// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IProtocolRevenueManager {

    struct AuctionRevenueSplit {
        uint64 treasurySplit;
        uint64 nodeOperatorSplit;
        uint64 tnftHolderSplit;
        uint64 bnftHolderSplit;
    }

    function addAuctionRevenue(uint256 _validatorId) external payable;
    function distributeAuctionRevenue(uint256 _validatorId) external returns (uint256);

    function setEtherFiNodesManagerAddress(address _etherFiNodesManager) external;

    function getAccruedAuctionRevenueRewards(uint256 _validatorId) external returns (uint256);  
}
