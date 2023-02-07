// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {
    struct Bid {
        uint256 amount;
        uint256 timeOfBid;
        address bidderAddress;
        bool isActive;
        bytes bidderPublicKey;
    }

    function bidOnStake(
        bytes32[] calldata _merkleProof,
        bytes memory _bidderPublicKey
    ) external payable;

    function calculateWinningBid() external returns (uint256);

    function cancelBid(uint256 _bidId) external;

    // function increaseBid(uint256 _bidId) external payable;

    // function decreaseBid(uint256 _bidId, uint256 _amount) external;

    function getNumberOfActivebids() external view returns (uint256);

    function getBidOwner(uint256 _bidId) external view returns (address);

    function reEnterAuction(uint256 _bidId, address _withdrawSafe) external;

    function setDepositContractAddress(address _depositContractAddress)
        external;
}
