// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuctionManager {
    struct Bid {
        uint256 amount;
        uint256 bidderPubKeyIndex;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
    }

    function createBid(bytes32[] calldata _merkleProof)
        external
        payable
        returns (uint256);

    //function calculateWinningBid() external returns (uint256);
    function updateSelectedBidInformation(uint256 _bidId) external;

    function fetchWinningBid() external returns (uint256);

    function cancelBid(uint256 _bidId) external;

    function getNumberOfActivebids() external view returns (uint256);

    function getBidOwner(uint256 _bidId) external view returns (address);

    function reEnterAuction(uint256 _bidId) external;

    function setStakingManagerContractAddress(
        address _stakingManagerContractAddress
    ) external;

    function processAuctionFeeTransfer(uint256 _validatorId) external;

    function setEtherFiNodesManagerAddress(address _managerAddress) external;
    function setProtocolRevenueManager(address _protocolRevenueManager) external;
}
