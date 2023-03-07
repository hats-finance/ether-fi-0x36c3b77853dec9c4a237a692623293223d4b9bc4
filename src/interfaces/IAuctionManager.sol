// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuctionManager {
    struct Bid {
        uint256 bidId;
        uint256 amount;
        uint256 bidderPubKeyIndex;
        uint256 timeOfBid;
        bool isActive;
        bool isReserved;
        address bidderAddress;
        address stakerAddress;
    }

    function createBid(bytes32[] calldata _merkleProof)
        external
        payable
        returns (uint256 _bidId);

    function selectBid(uint256 _bidId, address _staker) external;

    function bidOnStake(bytes32[] calldata _merkleProof) external payable;

    function calculateWinningBid() external returns (uint256);

    function cancelBid(uint256 _bidId) external;

    function getNumberOfActivebids() external view returns (uint256);

    function getBidOwner(uint256 _bidId) external view returns (address);

    function reEnterAuction(uint256 _bidId) external;

    function setStakingManagerContractAddress(
        address _stakingManagerContractAddress
    ) external;

    function sendFundsToEtherFiNode(uint256 _validatorId) external;

    function setEtherFiNodesManagerAddress(address _managerAddress) external;
}
