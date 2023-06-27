// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IMembershipManager.sol";
import "./interfaces/IMembershipNFT.sol";

contract MembershipNFT is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable, IMembershipNFT {

    IMembershipManager membershipManager;

    string private contractMetadataURI; /// @dev opensea contract-level metadata
    uint256 public nextMintID;

    bool public mintingPaused;

    mapping(uint256 => uint256) public tokenTransferLocks;

    mapping (address => bool) public eapDepositProcessed;
    bytes32 public eapMerkleRoot;
    uint64[] public requiredEapPointsPerEapDeposit;

    address public admin;

    event MerkleUpdated(bytes32, bytes32);
    event MintingPaused(bool isPaused);
    event TokenLocked(uint256 indexed _tokenId, uint256 until);
    
    error DissallowZeroAddress();
    error MintingIsPaused();
    error InvalidEAPRollover();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata _metadataURI) external initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155_init(_metadataURI);
        nextMintID = 1;
    }

    function mint(address _to, uint256 _amount) external onlyMembershipManagerContract returns (uint256) {
        if (mintingPaused) revert MintingIsPaused();

        uint256 tokenId = nextMintID;
        _mint(_to, tokenId, _amount, "");
        nextMintID++;
        return tokenId;
    }

    function burn(address _from, uint256 _tokenId, uint256 _amount) onlyMembershipManagerContract external {
        _burn(_from, _tokenId, _amount);
    }

    /// @dev locks a token from being transferred for a number of blocks
    function incrementLock(uint256 _tokenId, uint256 blocks) onlyMembershipManagerContract external {
        uint256 target = block.number + blocks;

        // don't accidentally shorten an existing lock
        if (tokenTransferLocks[_tokenId] < target) {
            tokenTransferLocks[_tokenId] = target;
            emit TokenLocked(_tokenId, target);
        }
    }

    function processFreeMintForEapUserDeposit(address _user, uint256 _snapshotEthAmount, uint256 _points, bytes32[] calldata _merkleProof) onlyMembershipManagerContract external {
        if (eapDepositProcessed[_user] == true) revert InvalidEAPRollover();
        bytes32 leaf = keccak256(abi.encodePacked(_user, _snapshotEthAmount, _points));
        if (!MerkleProof.verify(_merkleProof, eapMerkleRoot, leaf)) revert InvalidEAPRollover(); 

        eapDepositProcessed[_user] = true;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  SETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function setMembershipManager(address _address) external onlyOwner {
        membershipManager = IMembershipManager(_address);
    }

    /// @notice Set up for EAP migration; Updates the merkle root, Set the required loyalty points per tier
    /// @param _newMerkleRoot new merkle root used to verify the EAP user data (deposits, points)
    /// @param _requiredEapPointsPerEapDeposit required EAP points per deposit for each tier
    function setUpForEap(bytes32 _newMerkleRoot, uint64[] calldata _requiredEapPointsPerEapDeposit) external onlyAdmin {
        bytes32 oldMerkleRoot = eapMerkleRoot;
        eapMerkleRoot = _newMerkleRoot;
        requiredEapPointsPerEapDeposit = _requiredEapPointsPerEapDeposit;
        emit MerkleUpdated(oldMerkleRoot, _newMerkleRoot);
    }

    /// @notice Updates the address of the admin
    /// @param _newAdmin the new address to set as admin
    function updateAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Cannot be address zero");
        admin = _newAdmin;
    }
    
    function setMintingPaused(bool _paused) external onlyAdmin {
        mintingPaused = _paused;
        emit MintingPaused(_paused);
    }

    //--------------------------------------------------------------------------------------
    //---------------------------------  INTERNAL FUNCTIONS  -------------------------------
    //--------------------------------------------------------------------------------------

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}


    error RequireTokenUnlocked();
    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal override {

        // exempty mints and burns from checks
        if (_from == address(0x00) || _to == address(0x00)) {
            return;
        }

        // prevent transfers if token is locked
        for (uint256 x; x < _ids.length; ++x) {
            if (block.number < tokenTransferLocks[_ids[x]]) revert RequireTokenUnlocked();
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

    function accruedStakingRewardsOf(uint256 _tokenId) public view returns (uint256) {
        (uint96 rewardsLocalIndex,,,,, uint8 tier,) = membershipManager.tokenData(_tokenId);
        (uint128 amounts, ) = membershipManager.tokenDeposits(_tokenId);
        (uint96[] memory globalIndex, ) = membershipManager.calculateGlobalIndex();
        uint256 rewards = (globalIndex[tier] - rewardsLocalIndex) * amounts / 1 ether;
        return rewards;
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
        return membershipPointsEarning(_tokenId, prevPointsAccrualTimestamp, block.timestamp);
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

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function membershipPointsEarning(uint256 _tokenId, uint256 _since, uint256 _until) public view returns (uint40) {
        (uint128 amounts, uint128 amountStakedForPoints) = membershipManager.tokenDeposits(_tokenId);
        if (amounts == 0 && amountStakedForPoints == 0) {
            return 0;
        }

        uint16 pointsBoostFactor = membershipManager.pointsBoostFactor();
        uint16 pointsGrowthRate = membershipManager.pointsGrowthRate();

        uint256 elapsed = _until - _since;
        uint256 effectiveBalanceForEarningPoints = amounts + ((10000 + pointsBoostFactor) * amountStakedForPoints) / 10000;
        uint256 earning = effectiveBalanceForEarningPoints * elapsed * pointsGrowthRate / 10000;

        // 0.001 ether   membership points earns 1     wei   points per day
        // == 1  ether   membership points earns 1     kwei  points per day
        // == 1  Million membership points earns 1     gwei  points per day
        // type(uint40).max == 2^40 - 1 ~= 4 * (10 ** 12) == 1000 gwei
        // - A user with 1 Million membership points can earn points for 1000 days
        earning = _min((earning / 1 days) / 0.001 ether, type(uint40).max);
        return uint40(earning);
    }

    /// @notice Converts meTokens points to EAP tokens.
    /// @dev This function allows users to convert their EAP points to membership {loyalty, tier} tokens.
    /// @param _eapPoints The amount of EAP points
    /// @param _ethAmount The amount of ETH deposit in the EAP (or converted amounts for ERC20s)
    function convertEapPoints(uint256 _eapPoints, uint256 _ethAmount) public view returns (uint40, uint40) {
        uint256 loyaltyPoints = _min(1e5 * _eapPoints / 1 days , type(uint40).max);        
        uint256 eapPointsPerDeposit = _eapPoints / (_ethAmount / 0.001 ether);
        uint8 tierId = 0;
        while (tierId < requiredEapPointsPerEapDeposit.length 
                && eapPointsPerDeposit >= requiredEapPointsPerEapDeposit[tierId]) {
            tierId++;
        }
        tierId -= 1;
        (,, uint40 requiredTierPoints, ) = membershipManager.tierData(tierId);
        return (uint40(loyaltyPoints), requiredTierPoints);
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
    function setContractMetadataURI(string calldata _newURI) external onlyAdmin {
        contractMetadataURI = _newURI;
    }

    /// @dev erc1155 metadata extension
    function setMetadataURI(string calldata _newURI) external onlyAdmin {
        _setURI(_newURI);
    }

    /// @dev alert opensea to a metadata update
    function alertMetadataUpdate(uint256 id) public onlyAdmin {
        emit MetadataUpdate(id);
    }

    /// @dev alert opensea to a metadata update
    function alertBatchMetadataUpdate(uint256 startID, uint256 endID) public onlyAdmin {
        emit BatchMetadataUpdate(startID, endID);
    }

    //--------------------------------------------------------------------------------------
    //------------------------------------  MODIFIER  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }
}
