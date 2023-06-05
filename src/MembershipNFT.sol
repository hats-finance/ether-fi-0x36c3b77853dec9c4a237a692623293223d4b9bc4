// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import "./interfaces/ImeETH.sol";

contract MembershipNFT is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable {

    ImeETH meETH;

    string private contractMetadataURI; /// @dev opensea contract-level metadata
    uint256 public nextMintID;

    uint256[10] public gap;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
    }

    // TODO(dave): permissions
    function mint(address _to, uint256 _amount) external returns (uint256) {
        uint256 tokenId = nextMintID++;
        _mint(_to, tokenId, _amount, "");
    }

    // TODO(dave): permissions
    function burn(address _from, uint256 _tokenId, uint256 _amount) external {
        _burn(_from, _tokenId, _amount);
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    error IncorrectFeePercentage();
    error IncorrectCaller();

    function setMeETH(address _address) external onlyOwner {
        meETH = ImeETH(_address);
    }

    //--------------------------------------------------------------------------------------
    //---------------------------------  INTERNAL FUNCTIONS  -------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function valueOf(uint256 _tokenId) public view returns (uint256) {
        (uint96 rewardsLocalIndex,,,,, uint8 tier,) = meETH.tokenData(_tokenId);
        (uint128 amounts, uint128 amountStakedForPoints) = meETH.tokenDeposits(_tokenId);
        (uint96[] memory globalIndex, ) = meETH.calculateGlobalIndex();
        uint256 rewards = (globalIndex[tier] - rewardsLocalIndex) * amounts / 1 ether;
        return amounts + rewards + amountStakedForPoints;
    }

    function loyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        (, uint40 baseLoyaltyPoints,,,,,) = meETH.tokenData(_tokenId);
        uint256 pointsEarning = accruedLoyaltyPointsOf(_tokenId);
        uint256 total = _min(baseLoyaltyPoints + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierPointsOf(uint256 _tokenId) public view returns (uint40) {
        (,, uint40 baseTierPoints,,,,) = meETH.tokenData(_tokenId);
        uint256 pointsEarning = accruedTierPointsOf(_tokenId);
        uint256 total = _min(baseTierPoints + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierOf(uint256 _tokenId) public view returns (uint8) {
        (,,,,, uint8 tier,) = meETH.tokenData(_tokenId);
        return tier;
    }

    function claimableTier(uint256 _tokenId) public view returns (uint8) {
        uint40 tierPoints = tierPointsOf(_tokenId);
        return meETH.tierForPoints(tierPoints);
    }

    function accruedLoyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        (,,, uint32 prevPointsAccrualTimestamp,,,) = meETH.tokenData(_tokenId);
        return meETH.membershipPointsEarning(_tokenId, prevPointsAccrualTimestamp, block.timestamp);
    }

    function accruedTierPointsOf(uint256 _tokenId) public view returns (uint40) {
        (uint128 amounts, uint128 amountStakedForPoints) = meETH.tokenDeposits(_tokenId);
        if (amounts == 0 && amountStakedForPoints == 0) {
            return 0;
        } 
        (,,, uint32 prevPointsAccrualTimestamp,,,) = meETH.tokenData(_tokenId);
        uint256 tierPointsPerDay = 24; // 1 per an hour
        uint256 earnedPoints = (uint32(block.timestamp) - prevPointsAccrualTimestamp) * tierPointsPerDay / 1 days;
        uint256 effectiveBalanceForEarningPoints = amounts + ((10000 + meETH.pointsBoostFactor()) * amountStakedForPoints) / 10000;
        earnedPoints = earnedPoints * effectiveBalanceForEarningPoints / (amounts + amountStakedForPoints);
        return uint40(earnedPoints);
    }

    error OnlyTokenOwner();
    error OncePerMonth();
    error InvalidAllocation();
    error ExceededMaxDeposit();

    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) public view returns (bool) {
        (,,,, uint32 prevTopUpTimestamp,,) = meETH.tokenData(_tokenId);
        (uint128 amounts, uint128 amountStakedForPoints) = meETH.tokenDeposits(_tokenId);
        uint256 monthInSeconds = 28 days;
        uint256 maxDeposit = ((amounts + amountStakedForPoints) * meETH.maxDepositTopUpPercent()) / 100;
        if (balanceOf(msg.sender, _tokenId) != 1) revert OnlyTokenOwner();
        if (block.timestamp - uint256(prevTopUpTimestamp) < monthInSeconds) revert OncePerMonth();
        if (_totalAmount != _amount + _amountForPoints) revert InvalidAllocation();
        if (_totalAmount > maxDeposit) revert ExceededMaxDeposit();
        
        return true;
    }

    function isWithdrawable(uint256 _tokenId, uint256 _withdrawalAmount) public view returns (bool) {
        // cap withdrawals to 50% of lifetime max balance. Otherwise need to fully withdraw and burn NFT
        (uint128 amounts, uint128 amountStakedForPoints) = meETH.tokenDeposits(_tokenId);
        uint256 totalDeposit = amounts + amountStakedForPoints;
        uint256 highestDeposit = allTimeHighDepositOf(_tokenId);
        return (totalDeposit - _withdrawalAmount >= highestDeposit / 2);
    }

    function allTimeHighDepositOf(uint256 _tokenId) public view returns (uint256) {
        (uint128 amounts, uint128 amountStakedForPoints) = meETH.tokenDeposits(_tokenId);
        uint256 totalDeposit = amounts + amountStakedForPoints;
        return _max(totalDeposit, meETH.allTimeHighDepositAmount(_tokenId));        
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _b : _a;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _a : _b;
    }

    //--------------------------------------------------------------------------------------
    //---------------------------------- NFT METADATA --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @dev ERC-4906 This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev ERC-4906 This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.    
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);


    /// @notice OpenSea contract-level metadata
    function contractURI() public view returns (string memory) {
        return contractMetadataURI;
    }

    /// @dev opensea contract-level metadata
    function setContractMetadataURI(string calldata _newURI) external onlyOwner {
        contractMetadataURI = _newURI;
    }

    /// @dev erc1155 metadata extension
    function setMetadataURI(string calldata _newURI) external onlyOwner {
        _setURI(_newURI);
    }

    /// @dev alert opensea to a metadata update
    function alertMetadataUpdate(uint256 id) public onlyOwner {
        emit MetadataUpdate(id);
    }

    /// @dev alert opensea to a metadata update
    function alertBatchMetadataUpdate(uint256 startID, uint256 endID) public onlyOwner {
        emit BatchMetadataUpdate(startID, endID);
    }

}


