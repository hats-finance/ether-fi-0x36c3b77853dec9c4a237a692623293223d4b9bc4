// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./interfaces/IeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IWithdrawRequestNFT.sol";

contract WithdrawRequestNFT is ERC721Upgradeable, UUPSUpgradeable, OwnableUpgradeable {
    ILiquidityPool public liquidityPool;
    IeETH public eETH; 

    mapping(uint32 => IWithdrawRequestNFT.WithdrawRequest) private _requests;
    uint32 public nextRequestId;
    uint32 public lastFinalizedRequestId;

    address public DEPRECATED_admin;
    mapping(address => bool) public admins;

    event WithdrawRequestCreated(uint32 requestId, uint256 amountOfEEth, uint256 shareOfEEth, address owner);
    event WithdrawRequestClaimed(uint32 requestId, uint256 amountOfEEth, uint256 burntShareOfEEth, address owner);

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
        nextRequestId = 1;
    }

    function requestWithdraw(uint96 amountOfEEth, uint96 shareOfEEth, address recipient) external payable onlyLiquidtyPool returns (uint32) {
        uint32 requestId = nextRequestId;
        nextRequestId++;
        _requests[requestId] = IWithdrawRequestNFT.WithdrawRequest(amountOfEEth, shareOfEEth, true);
        _safeMint(recipient, requestId);

        emit WithdrawRequestCreated(uint32(requestId), amountOfEEth, shareOfEEth, recipient);
        return requestId;
    }

    function claimWithdraw(uint32 tokenId) external {
        require(tokenId <= nextRequestId, "Request does not exist");
        require(tokenId <= lastFinalizedRequestId, "Request is not finalized");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");

        IWithdrawRequestNFT.WithdrawRequest storage request = _requests[tokenId];
        require(request.isValid, "Request is not valid");

        // send the lesser value of the originally requested amount of eEth or the current eEth value of the shares
        uint256 amountForShares = liquidityPool.amountForShare(request.shareOfEEth);
        uint256 amountToTransfer = (request.amountOfEEth < amountForShares) ? request.amountOfEEth : amountForShares;
        require(amountToTransfer > 0, "Amount to transfer is zero");

        // transfer eth to requester
        address recipient = ownerOf(tokenId);
        _burn(tokenId);
        delete _requests[tokenId];

        uint256 amountBurnedShare = liquidityPool.withdraw(recipient, amountToTransfer);

        emit WithdrawRequestClaimed(uint32(tokenId), amountToTransfer, amountBurnedShare, recipient);
    }
    
    // add function to transfer accumulated shares to admin

    function getRequest(uint32 requestId) external view returns (IWithdrawRequestNFT.WithdrawRequest memory) {
        return _requests[requestId];
    }

    function isFinalized(uint32 requestId) external view returns (bool) {
        return requestId <= lastFinalizedRequestId;
    }

    function finalizeRequests(uint32 requestId) external onlyAdmin {
        lastFinalizedRequestId = requestId;
    }

    function invalidateRequest(uint32 requestId) external onlyAdmin {
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

    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        admins[_address] = _isAdmin;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "Caller is not the admin");
        _;
    }

    modifier onlyLiquidtyPool() {
        require(msg.sender == address(liquidityPool), "Caller is not the liquidity pool");
        _;
    }
}