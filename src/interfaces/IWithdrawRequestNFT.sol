// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isFinalized;
        bool    isClaimed;
    }

    function initialize() external;
    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester) external payable;
    function claimWithdraw(uint256 requestId) external returns (WithdrawRequest memory);
    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);
    function requestIsFinalized(uint256 requestId) external view returns (bool);
    function getNextRequestId() external view returns (uint256);
    function finalizeRequests(uint256 upperBound) external;
    function updateAdmin(address _newAdmin) external;
    function updateLiqudityPool(address _newLiquidityPool) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}
