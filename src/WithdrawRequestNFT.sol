// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract WithdrawRequestNFT is ERC721Upgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;

    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isFinalized;
        bool    isClaimed;
    }

    Counters.Counter private _requestIds;
    mapping(uint256 => WithdrawRequest) private _requests;
    uint256 private _nextRequestId = 1;
    address public admin;
    address public liquidityPool;

    constructor() ERC721Upgradeable() {
        admin = msg.sender;
    }

    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address requester) external payable {
        uint256 requestId = _nextRequestId;
        _nextRequestId++;
        _requests[requestId] = WithdrawRequest(amountOfEEth, shareOfEEth, false, false);
        _safeMint(msg.sender, requestId);
    }

    function claimWithdraw(uint256 requestId) external {
        WithdrawRequest storage request = _requests[requestId];
        require(request.requester == msg.sender, "Not authorized to claim");
        require(address(this).balance >= request.amount, "Insufficient funds");
        _burn(requestId);
        payable(msg.sender).transfer(request.amount);
        delete _requests[requestId];
    }

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory) {
        return _requests[requestId];
    }

    function getNextRequestId() external view returns (uint256) {
        return _nextRequestId;
    }

    function finalizeRequests(uint256 upperBound) external onlyAdmin() {
        for (uint256 i = 1; i <= upperBound; i++) {
            WithdrawRequest storage request = _requests[i];
            if (!request.isFinalized) {
                request.isFinalized = true;
            }
        }
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Cannot be address zero");
        admin = _newAdmin;
    }

    function updateLiqudityPool(address _newLiquidityPool) external onlyAdmin {
        require(_newLiquidityPool != address(0), "Cannot be address zero");
        liquidityPool = _newLiquidityPool;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }
}