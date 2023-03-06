// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IAuction {
    struct Bid {
        uint256 amount;
        uint256 bidderPubKeyIndex;
        uint256 timeOfBid;
        bool isActive;
        bool isReserverd;
        address bidderAddress;
        address stakerAddress;
    }

    function bidOnStake(bytes32[] calldata _merkleProof) external payable;

    function calculateWinningBid() external returns (uint256);

    function cancelBid(uint256 _bidId) external;

    function getNumberOfActivebids() external view returns (uint256);

    function getBidOwner(uint256 _bidId) external view returns (address);

    function reEnterAuction(uint256 _bidId) external;

    function setDepositContractAddress(address _depositContractAddress)
        external;

    function sendFundsToWithdrawSafe(uint256 _validatorId, uint256 _stakeId)
        external;

    function setManagerAddress(address _managerAddress) external;
}
