// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {

    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
    }

    function bidOnStake(bytes32[] calldata _merkleProof) external payable;

    function disableBidding() external returns (address);

    function enableBidding() external;

    function cancelBid(uint256 _bidId) external;

    function updateBid(uint256 _bidId) external payable;

    function getNumberOfActivebids() external view returns (uint256);

    function setDepositContractAddress(address _depositContractAddress)
        external;
}
