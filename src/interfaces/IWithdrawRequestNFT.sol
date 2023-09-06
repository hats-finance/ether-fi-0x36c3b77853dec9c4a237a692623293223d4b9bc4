// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IWithdrawRequestNFT {
    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isValid;
    }

    function initialize() external;
    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester) external payable returns (uint32);
    function claimWithdraw(uint32 requestId) external returns (WithdrawRequest memory);

    function getRequest(uint32 requestId) external view returns (WithdrawRequest memory);
    function isFinalized(uint32 requestId) external view returns (bool);
    function ownerOf(uint32 tokenId) external view returns (address);

    function getNextRequestId() external view returns (uint32);

    function invalidateRequest(uint32 requestId) external;
    function finalizeRequests(uint32 upperBound) external;
    function updateAdmin(address _address, bool _isAdmin) external;
    function updateLiqudityPool(address _newLiquidityPool) external;

    function nextRequestId() external view returns (uint32);
}
