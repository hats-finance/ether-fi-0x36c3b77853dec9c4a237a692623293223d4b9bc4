// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuctionManager {
    struct Bid {
        uint256 amount;
        uint64 bidderPubKeyIndex;
        address bidderAddress;
        bool isActive;
    }

    function createBid(
        uint256 _bidSize,
        uint256 _bidAmount
    ) external payable returns (uint256[] memory);

    function updateSelectedBidInformation(uint256 _bidId) external;

    function cancelBid(uint256 _bidId) external;

    function getBidOwner(uint256 _bidId) external view returns (address);

    function reEnterAuction(uint256 _bidId) external;

    function setStakingManagerContractAddress(
        address _stakingManagerContractAddress
    ) external;

    function whitelistAddress(address _user) external;

    function processAuctionFeeTransfer(uint256 _validatorId) external;

    function isBidActive(uint256 _bidId) external view returns (bool);

    function numberOfActiveBids() external view returns (uint256);

    function isWhitelisted(
        address _user
    ) external view returns (bool whitelisted);

    function setProtocolRevenueManager(
        address _protocolRevenueManager
    ) external;
}
