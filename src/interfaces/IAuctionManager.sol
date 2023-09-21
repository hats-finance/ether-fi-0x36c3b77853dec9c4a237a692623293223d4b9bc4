// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuctionManager {
    struct Bid {
        uint256 amount;
        uint64 bidderPubKeyIndex;
        address bidderAddress;
        bool isActive;
    }

    function initialize(address _nodeOperatorManagerContract) external;
    function createBid(uint256 _bidSize, uint256 _bidAmount) external payable returns (uint256[] memory);
    function cancelBidBatch(uint256[] calldata _bidIds) external;
    function cancelBid(uint256 _bidId) external;
    function updateSelectedBidInformation(uint256 _bidId) external;
    function reEnterAuction(uint256 _bidId) external;
    function processAuctionFeeTransfer(uint256 _validatorId) external;
    function transferAccumulatedRevenue() external;
    function disableWhitelist() external;
    function enableWhitelist() external;
    function pauseContract() external;
    function unPauseContract() external;
    function getBidOwner(uint256 _bidId) external view returns (address);
    function isBidActive(uint256 _bidId) external view returns (bool);
    function getImplementation() external view returns (address);
    function setStakingManagerContractAddress(address _stakingManagerContractAddress) external;
    function setMembershipManagerContractAddress(address _membershipManagerContractAddress) external;
    function setMinBidPrice(uint64 _newMinBidAmount) external;
    function setMaxBidPrice(uint64 _newMaxBidAmount) external;
    function setAccumulatedRevenueThreshold(uint128 _newThreshold) external;
    function updateWhitelistMinBidAmount(uint128 _newAmount) external;
    function updateNodeOperatorManager(address _address) external;
    function updateAdmin(address _address, bool _isAdmin) external;
    function numberOfActiveBids() external view returns (uint256);
}
