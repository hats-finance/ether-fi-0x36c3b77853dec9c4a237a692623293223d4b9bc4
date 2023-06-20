// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import "./interfaces/IMembershipManager.sol";
import "./interfaces/IMembershipNFT.sol";

contract MembershipNFT is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable, IMembershipNFT {

    IMembershipManager membershipManager;

    string private contractMetadataURI; /// @dev opensea contract-level metadata
    uint256 public nextMintID;

    mapping(uint256 => uint256) public tokenLocks;
    event TokenLocked(uint256 indexed _tokenId, uint256 until);

    uint256[9] public gap;


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    error DissallowZeroAddress();
    function initialize(string calldata _metadataURI) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155_init(_metadataURI);
    }

    function mint(address _to, uint256 _amount) external onlyMembershipManagerContract returns (uint256) {
        uint256 tokenId = nextMintID++;
        _mint(_to, tokenId, _amount, "");
        return tokenId;
    }

    function burn(address _from, uint256 _tokenId, uint256 _amount) onlyMembershipManagerContract external {
        _burn(_from, _tokenId, _amount);
    }

    error OnlyTokenOwner();
    error RequireTokenUnlocked();
    error InvalidLock();

    /// @notice locks a token for the specified number of blocks preventing withdrawing or burning.
    ///         A token must be locked for it to be transferred. A user should ONLY purchase a token
    ///         if the remaining time on the lock is safely above the number of blocks the user expects
    ///         the TX to be confirmed in.
    /// @dev lock will expire immediately once the token is transferred
    /// @param _tokenId ID of the token to lock
    /// @param _blocks how many blocks to lock the token for
    function lockToken(uint256 _tokenId, uint256 _blocks) external {
        if (balanceOfUser(msg.sender, _tokenId) != 1) revert OnlyTokenOwner();
        if (block.number < tokenLocks[_tokenId]) revert RequireTokenUnlocked();
        if (_blocks == 0) revert InvalidLock();

        uint256 until = block.number + _blocks;
        tokenLocks[_tokenId] = block.number + _blocks;
        emit TokenLocked(_tokenId, until);
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function setMembershipManager(address _address) external onlyOwner {
        membershipManager = IMembershipManager(_address);
    }

    //--------------------------------------------------------------------------------------
    //---------------------------------  INTERNAL FUNCTIONS  -------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    error RequireTokenLocked();
    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal override {

        // exempt mints/burns from check
        if (_from == address(0x00) || _to == address(0x00)) {
            return;
        }

        // prevent transfers if token is not locked
        for (uint256 x; x < _ids.length; ++x) {
            if (block.number >= tokenLocks[_ids[x]]) revert RequireTokenLocked();
        }
    }

    function _afterTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal override {

        // reset locks so new owner has control
        for (uint256 x; x < _ids.length; ++x) {
            tokenLocks[_ids[x]] = 0;
        }
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function balanceOfUser(address _user, uint256 _id) public returns (uint256) {
        return balanceOf(_user, _id);
    }

    function valueOf(uint256 _tokenId) public view returns (uint256) {
        (uint96 rewardsLocalIndex,,,,, uint8 tier,) = membershipManager.tokenData(_tokenId);
        (uint128 amounts, uint128 amountStakedForPoints) = membershipManager.tokenDeposits(_tokenId);
        (uint96[] memory globalIndex, ) = membershipManager.calculateGlobalIndex();
        uint256 rewards = (globalIndex[tier] - rewardsLocalIndex) * amounts / 1 ether;
        return amounts + rewards + amountStakedForPoints;
    }

    function loyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        (, uint40 baseLoyaltyPoints,,,,,) = membershipManager.tokenData(_tokenId);
        uint256 pointsEarning = accruedLoyaltyPointsOf(_tokenId);
        uint256 total = _min(baseLoyaltyPoints + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierPointsOf(uint256 _tokenId) public view returns (uint40) {
        (,, uint40 baseTierPoints,,,,) = membershipManager.tokenData(_tokenId);
        uint256 pointsEarning = accruedTierPointsOf(_tokenId);
        uint256 total = _min(baseTierPoints + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierOf(uint256 _tokenId) public view returns (uint8) {
        (,,,,, uint8 tier,) = membershipManager.tokenData(_tokenId);
        return tier;
    }

    function claimableTier(uint256 _tokenId) public view returns (uint8) {
        uint40 tierPoints = tierPointsOf(_tokenId);
        return membershipManager.tierForPoints(tierPoints);
    }

    function accruedLoyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        (,,, uint32 prevPointsAccrualTimestamp,,,) = membershipManager.tokenData(_tokenId);
        return membershipManager.membershipPointsEarning(_tokenId, prevPointsAccrualTimestamp, block.timestamp);
    }

    function accruedTierPointsOf(uint256 _tokenId) public view returns (uint40) {
        (uint128 amounts, uint128 amountStakedForPoints) = membershipManager.tokenDeposits(_tokenId);
        if (amounts == 0 && amountStakedForPoints == 0) {
            return 0;
        }
        (,,, uint32 prevPointsAccrualTimestamp,,,) = membershipManager.tokenData(_tokenId);
        uint256 tierPointsPerDay = 24; // 1 per an hour
        uint256 earnedPoints = (uint32(block.timestamp) - prevPointsAccrualTimestamp) * tierPointsPerDay / 1 days;
        uint256 effectiveBalanceForEarningPoints = amounts + ((10000 + membershipManager.pointsBoostFactor()) * amountStakedForPoints) / 10000;
        earnedPoints = earnedPoints * effectiveBalanceForEarningPoints / (amounts + amountStakedForPoints);
        return uint40(earnedPoints);
    }

    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) public view returns (bool) {
        return membershipManager.canTopUp(_tokenId, _totalAmount, _amount, _amountForPoints);
    }

    function isWithdrawable(uint256 _tokenId, uint256 _withdrawalAmount) public view returns (bool) {
        // cap withdrawals to 50% of lifetime max balance. Otherwise need to fully withdraw and burn NFT
        (uint128 amounts, uint128 amountStakedForPoints) = membershipManager.tokenDeposits(_tokenId);
        uint256 totalDeposit = amounts + amountStakedForPoints;
        uint256 highestDeposit = allTimeHighDepositOf(_tokenId);
        return (totalDeposit - _withdrawalAmount >= highestDeposit / 2);
    }

    function allTimeHighDepositOf(uint256 _tokenId) public view returns (uint256) {
        (uint128 amounts, uint128 amountStakedForPoints) = membershipManager.tokenDeposits(_tokenId);
        uint256 totalDeposit = amounts + amountStakedForPoints;
        return _max(totalDeposit, membershipManager.allTimeHighDepositAmount(_tokenId));        
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _b : _a;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _a : _b;
    }

    error OnlyMembershipManagerContract();
    modifier onlyMembershipManagerContract() {
        if (msg.sender != address(membershipManager)) revert OnlyMembershipManagerContract();
        _;
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
