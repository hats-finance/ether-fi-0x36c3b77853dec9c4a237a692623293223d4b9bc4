// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IeETH.sol";
import "./interfaces/ILiquidityPool.sol";

contract WithdrawRequestNFT is ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;

    struct WithdrawRequest {
        uint96  amountOfEEth;
        uint96  shareOfEEth;
        bool    isValid;
    }

    mapping(uint256 => WithdrawRequest) private _requests;
    uint256 private _nextRequestId;
    address public admin;
    uint256 public lastFinalizedRequestId;
    ILiquidityPool public liquidityPool;
    IeETH public eETH; 


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _liquidityPoolAddress, address _eEthAddress) initializer external {
        require(_liquidityPoolAddress != address(0), "No zero addresses");
        require(_eEthAddress != address(0), "No zero addresses");
        __ERC721_init("Withdraw Request NFT", "WithdrawRequestNFT");
        __Ownable_init();
        __UUPSUpgradeable_init();

        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
        eETH = IeETH(_eEthAddress);
        _nextRequestId = 1;
    }

    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address recipient) external payable onlyLiquidtyPool returns (uint256) {
        uint256 requestId = _nextRequestId;
        _nextRequestId++;
        _requests[requestId] = WithdrawRequest(amountOfEEth, shareOfEEth, true);
        _safeMint(recipient, requestId);
        return requestId;
    }

    function claimWithdraw(uint256 tokenId) external {
        require(tokenId <= _nextRequestId, "Request does not exist");
        require(tokenId <= lastFinalizedRequestId, "Request is not finalized");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");

        WithdrawRequest storage request = _requests[tokenId];
        require(request.isValid, "Request is not valid");

        // send the lesser value of the originally requested amount of eEth or the current eEth value of the shares
        uint256 amountForShares = liquidityPool.amountForShare(request.shareOfEEth);
        uint256 amountToTransfer = (request.amountOfEEth < amountForShares) ? request.amountOfEEth : amountForShares;
        require(amountToTransfer > 0, "Amount to transfer is zero");

        // transfer eth to requester
        address recipient = ownerOf(tokenId);
        liquidityPool.withdraw(recipient, amountToTransfer);
        _burn(tokenId);
        delete _requests[tokenId];
    }
    
    // add function to transfer accumulated shares to admin

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory) {
        return _requests[requestId];
    }

    function isFinalized(uint256 requestId) external view returns (bool) {
        return requestId <= lastFinalizedRequestId;
    }

    function getNextRequestId() external view returns (uint256) {
        return _nextRequestId;
    }

    function finalizeRequests(uint256 requestId) external onlyAdmin {
        lastFinalizedRequestId = requestId;
    }

    function invalidateRequest(uint256 requestId) external onlyAdmin {
        _requests[requestId].isValid = false;
    }

    function updateLiquidityPool(address _newLiquidityPool) external onlyAdmin {
        require(_newLiquidityPool != address(0), "Cannot be address zero");
        liquidityPool = ILiquidityPool(_newLiquidityPool);
    }

    function updateEEth(address _newEEth) external onlyAdmin {
        require(_newEEth != address(0), "Cannot be address zero");
        eETH = IeETH(_newEEth);
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Cannot be address zero");
        admin = _newAdmin;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    modifier onlyLiquidtyPool() {
        require(msg.sender == address(liquidityPool), "Caller is not the liquidity pool");
        _;
    }
}