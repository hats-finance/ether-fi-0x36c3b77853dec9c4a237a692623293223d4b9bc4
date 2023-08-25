// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isValid;
    }

    function initialize() external;
    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester) external payable returns (uint256);
    function claimWithdraw(uint256 requestId) external returns (WithdrawRequest memory);
    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);
    function isFinalized(uint256 requestId) external view returns (bool);
    function getNextRequestId() external view returns (uint256);
    function invalidateRequest(uint256 requestId) external;
    function finalizeRequests(uint256 upperBound) external;
    function updateAdmin(address _newAdmin) external;
    function updateLiqudityPool(address _newLiquidityPool) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}
