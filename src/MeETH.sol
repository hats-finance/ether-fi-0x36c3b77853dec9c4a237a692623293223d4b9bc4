// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

import "./interfaces/IeETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";

contract MeETH is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable, ImeETH {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IeETH public eETH;
    ILiquidityPool public liquidityPool;

    mapping (uint256 => TokenDeposit) public tokenDeposits;
    mapping (uint256 => TokenData) public tokenData;
    TierDeposit[] public tierDeposits;
    TierData[] public tierData;

    mapping (address => bool) public eapDepositProcessed;
    bytes32 public eapMerkleRoot;
    uint64[] public requiredEapPointsPerEapDeposit;

    uint32 public nextMintID;
    uint16 public pointsBoostFactor; // + (X / 10000) more points if staking rewards are sacrificed
    uint16 public pointsGrowthRate; // + (X / 10000) kwei points earnigs per 1 meETH per day
    uint56 public minDepositGwei;
    uint8  public maxDepositTopUpPercent;

    string private _metadataURI;    /// @dev base URI for all token metadata    

    uint256[23] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event FundsMigrated(address indexed user, uint256 _tokenId, uint256 _amount, uint256 _eapPoints, uint40 _loyaltyPoints, uint40 _tierPoints);
    event MerkleUpdated(bytes32, bytes32);

    /// @dev ERC-4906 This event emits when the metadata of a token is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFT.
    event MetadataUpdate(uint256 _tokenId);

    /// @dev ERC-4906 This event emits when the metadata of a range of tokens is changed.
    /// So that the third-party platforms such as NFT market could
    /// timely update the images and related attributes of the NFTs.    
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize(string calldata _newURI, address _eEthAddress, address _liquidityPoolAddress) external initializer {
        require(_eEthAddress != address(0), "No zero addresses");
        require(_liquidityPoolAddress != address(0), "No zero addresses");

        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC1155_init(_newURI);

        eETH = IeETH(_eEthAddress);
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);

        pointsBoostFactor = 10000;
        pointsGrowthRate = 10000;
        nextMintID = 0;
        minDepositGwei = (0.1 ether / 1 gwei);
        maxDepositTopUpPercent = 20;
    }

    /// @notice EarlyAdopterPool users can re-deposit and mint meETH claiming their points & tiers
    /// @dev The deposit amount must be greater than or equal to what they deposited into the EAP
    /// @param _points points of the user
    /// @param _ethAmount exact balance user has in the merkle snapshot
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    function wrapEthForEap(
        uint256 _ethAmount,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) external payable returns (uint256) {
        require(_points > 0, "You don't have any points to claim");
        require(msg.value >= _ethAmount, "Invalid deposit amount");
        require(eapDepositProcessed[msg.sender] == false, "You already made EAP deposit");
        _verifyEapUserData(msg.sender, _ethAmount, _points, _merkleProof);

        eapDepositProcessed[msg.sender] = true;
        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);

        (uint40 loyaltyPoints, uint40 tierPoints) = convertEapPoints(_points, _ethAmount);
        uint256 tokenId = _mintMembershipNFT(msg.sender, msg.value, loyaltyPoints, tierPoints);
        emit FundsMigrated(msg.sender, tokenId, msg.value, _points, loyaltyPoints, tierPoints);
        return tokenId;
    }

    function wrapEth(bytes32[] calldata _merkleProof) public payable returns (uint256) {
        require(msg.value / 1 gwei >= minDepositGwei, "Below minimum deposit");

        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);
        uint256 tokenId = _mintMembershipNFT(msg.sender, msg.value, 0, 0);
        return tokenId;
    }

    function wrapEEth(uint256 _amount) external isEEthStakingOpen returns (uint256) {
        require(_amount / 1 gwei >= minDepositGwei, "Below minimum deposit");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        eETH.transferFrom(msg.sender, address(this), _amount);
        uint256 tokenId = _mintMembershipNFT(msg.sender, _amount, 0, 0);
        return tokenId;
    }

    /// @notice Increase your deposit tied to this NFT within the configured percentage limit.
    /// @dev Can only be done once per month
    /// @param _tokenId ID of NFT token
    /// @param _amount amount of eth to increase effective balance by
    /// @param _amountForPoints amount of eth to increase balance earning increased loyalty rewards
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    function topUpDepositWithEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints, bytes32[] calldata _merkleProof) public payable {
        TokenData storage token = tokenData[_tokenId];
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 maxDeposit = ((deposit.amounts + deposit.amountStakedForPoints) * maxDepositTopUpPercent) / 100;
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(block.timestamp - uint256(token.prevTopUpTimestamp) >= monthInSeconds, "Already topped up this month");
        require(msg.value <= maxDeposit, "Above maximum deposit");
        require(msg.value == _amount + _amountForPoints, "Invalid allocation");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);

        _mintInternal(_tokenId, _amount + _amountForPoints);
        _stakeForPoints(_tokenId, _amountForPoints);
        token.prevTopUpTimestamp = uint32(block.timestamp);
    }

    /// @notice Increase your deposit tied to this NFT within the configured percentage limit.
    /// @dev Can only be done once per month
    /// @param _tokenId ID of NFT token
    /// @param _amount amount of eth to increase effective balance by
    /// @param _amountForPoints amount of eth to increase balance earning increased loyalty rewards
    function topUpDepositWithEEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints) public {
        TokenData storage token = tokenData[_tokenId];
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 maxDeposit = ((deposit.amounts + deposit.amountStakedForPoints) * maxDepositTopUpPercent) / 100;
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(block.timestamp - uint256(token.prevTopUpTimestamp) >= monthInSeconds, "Already topped up this month");
        require(eETH.balanceOf(msg.sender) >= _amount + _amountForPoints, "Not enough balance");
        require(_amount + _amountForPoints <= maxDeposit, "Above maximum deposit");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        eETH.transferFrom(msg.sender, address(this), _amount + _amountForPoints);
        
        _mintInternal(_tokenId, _amount + _amountForPoints);
        _stakeForPoints(_tokenId, _amountForPoints);
        token.prevTopUpTimestamp = uint32(block.timestamp);
    }

    function unwrapForEEth(uint256 _tokenId, uint256 _amount) public isEEthStakingOpen {
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(_amount > 0, "You cannot unwrap 0 meETH");
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        uint256 unwrappableBalance = deposit.amounts - deposit.amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        uint256 prevAmount = tokenDeposits[_tokenId].amounts;
        _burn(_tokenId, _amount);
        _applyUnwrapPenalty(_tokenId, prevAmount, _amount);

        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function unwrapForEth(uint256 _tokenId, uint256 _amount) external {
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(address(liquidityPool).balance >= _amount, "Not enough ETH in the liquidity pool");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        uint256 prevAmount = tokenDeposits[_tokenId].amounts;
        _burn(_tokenId, _amount);
        _applyUnwrapPenalty(_tokenId, prevAmount, _amount);

        liquidityPool.withdraw(address(this), _amount);
        (bool sent, ) = address(msg.sender).call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function stakeForPoints(uint256 _tokenId, uint256 _amount) external {
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(tokenDeposits[_tokenId].amounts >= _amount, "Not enough balance to stake for points");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _stakeForPoints(_tokenId, _amount);
    }

    function unstakeForPoints(uint256 _tokenId, uint256 _amount) external {
        require(balanceOf(msg.sender, _tokenId) == 1, "Only token owner");
        require(tokenDeposits[_tokenId].amountStakedForPoints >= _amount, "Not enough balance staked");

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _unstakeForPoints(_tokenId, _amount);
    }

    function claimTier(uint256 _tokenId) public {
        uint8 oldTier = tierOf(_tokenId);
        uint8 newTier = claimableTier(_tokenId);
        if (oldTier == newTier) {
            return;
        }

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _claimTier(_tokenId, oldTier, newTier);
    }

    function claimPoints(uint256 _tokenId) public {
        TokenData storage token = tokenData[_tokenId];
        token.baseLoyaltyPoints = loyaltyPointsOf(_tokenId);
        token.baseTierPoints = tierPointsOf(_tokenId);
        token.prevPointsAccrualTimestamp = uint32(block.timestamp);
    }

    function claimStakingRewards(uint256 _tokenId) public {
        TokenData storage tokenData = tokenData[_tokenId];
        uint256 tier = tokenData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - tokenData.rewardsLocalIndex) * tokenDeposits[_tokenId].amounts / 1 ether;
        _incrementTokenDeposit(_tokenId, amount, 0);
        tokenData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    // EapPoints => (Loyalty Points, Tier Points)
    function convertEapPoints(uint256 _eapPoints, uint256 _ethAmount) public view returns (uint40, uint40) {
        uint256 loyaltyPoints = _min(1e5 * _eapPoints / 1 days , type(uint40).max);        
        uint256 eapPointsPerDeposit = _eapPoints / (_ethAmount / 0.001 ether);
        uint8 tierId = 0;
        while (tierId < requiredEapPointsPerEapDeposit.length 
                && eapPointsPerDeposit >= requiredEapPointsPerEapDeposit[tierId]) {
            tierId++;
        }
        tierId -= 1;
        uint256 tierPoints = tierData[tierId].requiredTierPoints;
        return (uint40(loyaltyPoints), uint40(tierPoints));
    }

    function updatePointsBoostFactor(uint16 _newPointsBoostFactor) public onlyOwner {
        pointsBoostFactor = _newPointsBoostFactor;
    }

    function updatePointsGrowthRate(uint16 _newPointsGrowthRate) public onlyOwner {
        pointsGrowthRate = _newPointsGrowthRate;
    }

    function distributeStakingRewards() external onlyOwner {
        (uint96[] memory globalIndex, uint128[] memory adjustedShares) = _calculateGlobalIndex();
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            uint256 amounts = liquidityPool.amountForShare(adjustedShares[i]);
            tierDeposits[i].shares = adjustedShares[i];
            tierDeposits[i].amounts = uint128(amounts);
            tierData[i].rewardsGlobalIndex = globalIndex[i];
        }
    }

    function addNewTier(uint40 _requiredTierPoints, uint24 _weight) external onlyOwner returns (uint256) {
        require(tierDeposits.length < type(uint8).max, "Cannot add more new tier");
        tierDeposits.push(TierDeposit(0, 0));
        tierData.push(TierData(0, 0, _requiredTierPoints, _weight));
        return tierDeposits.length - 1;
    }

    function setPoints(uint256 _tokenId, uint40 _loyaltyPoints, uint40 _tierPoints) external onlyOwner {
        TokenData storage token = tokenData[_tokenId];
        token.baseLoyaltyPoints = _loyaltyPoints;
        token.baseTierPoints = _tierPoints;
        token.prevPointsAccrualTimestamp = uint32(block.timestamp);
    }

    /// @notice Set up for EAP migration; Updates the merkle root, Set the required loyalty points per tier
    /// @param _newMerkleRoot new merkle root used to verify the EAP user data (deposits, points)
    /// @param _requiredEapPointsPerEapDeposit required EAP points per deposit for each tier
    function setUpForEap(bytes32 _newMerkleRoot, uint64[] calldata _requiredEapPointsPerEapDeposit) external onlyOwner {
        bytes32 oldMerkleRoot = eapMerkleRoot;
        eapMerkleRoot = _newMerkleRoot;
        requiredEapPointsPerEapDeposit = _requiredEapPointsPerEapDeposit;
        emit MerkleUpdated(oldMerkleRoot, _newMerkleRoot);
    }

    /// @notice Updates minimum valid deposit
    /// @param value minimum deposit in wei
    function setMinDepositWei(uint56 value) external onlyOwner {
        minDepositGwei = value;
    }

    /// @notice Updates minimum valid deposit
    /// @param percent integer percentage value
    function setMaxDepositTopUpPercent(uint8 percent) external onlyOwner {
        maxDepositTopUpPercent = percent;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    function _mintMembershipNFT(address to, uint256 _amount, uint40 _loyaltyPoints, uint40 _tierPoints) internal returns (uint256) {
        uint256 tokenId = nextMintID++;

        uint8 tier = _tierForPoints(_tierPoints);
        TokenData storage tokenData = tokenData[tokenId];
        tokenData.baseLoyaltyPoints = _loyaltyPoints;
        tokenData.baseTierPoints = _tierPoints;
        tokenData.prevPointsAccrualTimestamp = uint32(block.timestamp);
        tokenData.tier = tier;
        tokenData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
        _mintInternal(tokenId, _amount);
        _mint(to, tokenId, 1, "");

        emit TransferSingle(to, address(0), to, tokenId, 1);

        require(
            to.code.length == 0
                ? to != address(0)
                : IERC165Upgradeable(to).supportsInterface(type(IERC1155ReceiverUpgradeable).interfaceId) && 
                IERC1155ReceiverUpgradeable(to).onERC1155Received.selector == bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")),
            "UNSAFE_RECIPIENT"
        );

        return tokenId;
    }

    function _mintInternal(uint256 _tokenId, uint256 _amount) internal {
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(_tokenId);

        _incrementTokenDeposit(_tokenId, _amount, 0);
        _incrementTierDeposit(tier, _amount, share);
    }

    function _burn(uint256 _tokenId, uint256 _amount) internal {
        require(tokenDeposits[_tokenId].amounts >= _amount, "Not enough Balance");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(_tokenId);
        _decrementTokenDeposit(_tokenId, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }

    function _stakeForPoints(uint256 _tokenId, uint256 _amount) internal {
        uint256 tier = tierOf(_tokenId);
        tierData[tier].amountStakedForPoints += uint96(_amount);
        _incrementTokenDeposit(_tokenId, 0, _amount);
        _decrementTokenDeposit(_tokenId, _amount, 0);
    }

    function _unstakeForPoints(uint256 _tokenId, uint256 _amount) internal {
        uint256 tier = tierOf(_tokenId);
        tierData[tier].amountStakedForPoints -= uint96(_amount);
        _incrementTokenDeposit(_tokenId, _amount, 0);
        _decrementTokenDeposit(_tokenId, 0, _amount);
    }

    function _incrementTokenDeposit(uint256 _tokenId, uint256 _amount, uint256 _amountStakedForPoints) internal {
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        tokenDeposits[_tokenId] = TokenDeposit(
            deposit.amounts + uint128(_amount),
            deposit.amountStakedForPoints + uint128(_amountStakedForPoints)
        );
    }

    function _decrementTokenDeposit(uint256 _tokenId, uint256 _amount, uint256 _amountStakedForPoints) internal {
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        tokenDeposits[_tokenId] = TokenDeposit(
            deposit.amounts - uint128(_amount),
            deposit.amountStakedForPoints - uint128(_amountStakedForPoints)
        );
    }

    function _incrementTierDeposit(uint256 _tier, uint256 _amount, uint256 _shares) internal {
        TierDeposit memory deposit = tierDeposits[_tier];
        tierDeposits[_tier] = TierDeposit(
            deposit.shares + uint128(_shares),
            deposit.amounts + uint128(_amount)
        );
    }

    function _decrementTierDeposit(uint256 _tier, uint256 _amount, uint256 _shares) internal {
        TierDeposit memory deposit = tierDeposits[_tier];
        tierDeposits[_tier] = TierDeposit(
            deposit.shares - uint128(_shares),
            deposit.amounts - uint128(_amount)
        );
    }

    function _claimTier(uint256 _tokenId) internal {
        uint8 oldTier = tierOf(_tokenId);
        uint8 newTier = claimableTier(_tokenId);
        _claimTier(_tokenId, oldTier, newTier);
    }

    function _claimTier(uint256 _tokenId, uint8 _curTier, uint8 _newTier) internal {
        require(tierOf(_tokenId) == _curTier, "the account does not belong to the specified tier");
        if (_curTier == _newTier) {
            return;
        }

        uint256 amount = _min(tokenDeposits[_tokenId].amounts, tierDeposits[_curTier].amounts);
        uint256 share = liquidityPool.sharesForAmount(amount);
        uint256 amountStakedForPoints = tokenDeposits[_tokenId].amountStakedForPoints;

        tierData[_curTier].amountStakedForPoints -= uint96(amountStakedForPoints);
        _decrementTierDeposit(_curTier, amount, share);

        tierData[_newTier].amountStakedForPoints += uint96(amountStakedForPoints);
        _incrementTierDeposit(_newTier, amount, share);

        tokenData[_tokenId].rewardsLocalIndex = tierData[_newTier].rewardsGlobalIndex;
        tokenData[_tokenId].tier = _newTier;
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function _membershipPointsEarning(uint256 _tokenId, uint256 _since, uint256 _until) internal view returns (uint40) {
        TokenDeposit storage tokenDeposit = tokenDeposits[_tokenId];
        if (tokenDeposit.amounts == 0 && tokenDeposit.amountStakedForPoints == 0) {
            return 0;
        }

        uint256 elapsed = _until - _since;
        uint256 effectiveBalanceForEarningPoints = tokenDeposit.amounts + ((10000 + pointsBoostFactor) * tokenDeposit.amountStakedForPoints) / 10000;
        uint256 earning = effectiveBalanceForEarningPoints * elapsed * pointsGrowthRate / 10000;

        // 0.001 ether   meETH earns 1     wei   points per day
        // == 1  ether   meETH earns 1     kwei  points per day
        // == 1  Million meETH earns 1     gwei  points per day
        // type(uint40).max == 2^40 - 1 ~= 4 * (10 ** 12) == 1000 gwei
        // - A user with 1 Million meETH can earn points for 1000 days
        earning = _min((earning / 1 days) / 0.001 ether, type(uint40).max);
        return uint40(earning);
    }

    function _calculateGlobalIndex() internal view returns (uint96[] memory, uint128[] memory) {
        uint96[] memory globalIndex = new uint96[](tierDeposits.length);
        uint128[] memory adjustedShares = new uint128[](tierDeposits.length);
        uint256[] memory weightedTierRewards = new uint256[](tierDeposits.length);
        uint256[] memory tierRewards = new uint256[](tierDeposits.length);
        uint256 sumTierRewards = 0;
        uint256 sumWeightedTierRewards = 0;
        
        for (uint256 i = 0; i < weightedTierRewards.length; i++) {                        
            TierDeposit memory deposit = tierDeposits[i];
            uint256 rebasedAmounts = liquidityPool.amountForShare(deposit.shares);
            if (rebasedAmounts >= deposit.amounts) {
                tierRewards[i] = rebasedAmounts - deposit.amounts;
                weightedTierRewards[i] = tierData[i].weight * tierRewards[i];
            }
            globalIndex[i] = tierData[i].rewardsGlobalIndex;
            adjustedShares[i] = tierDeposits[i].shares;

            sumTierRewards += tierRewards[i];
            sumWeightedTierRewards += weightedTierRewards[i];
        }

        if (sumWeightedTierRewards > 0) {
            for (uint256 i = 0; i < weightedTierRewards.length; i++) {
                uint256 amountsEligibleForRewards = tierDeposits[i].amounts - tierData[i].amountStakedForPoints;
                if (amountsEligibleForRewards > 0) {
                    uint256 rescaledTierRewards = weightedTierRewards[i] * sumTierRewards / sumWeightedTierRewards;
                    uint256 delta = 1 ether * rescaledTierRewards / amountsEligibleForRewards;
                    require(uint256(globalIndex[i]) + uint256(delta) <= type(uint96).max, "overflow");
                    globalIndex[i] += uint96(delta);
                    if (tierRewards[i] > rescaledTierRewards) {
                        adjustedShares[i] -= uint128(liquidityPool.sharesForAmount(tierRewards[i] - rescaledTierRewards));
                    } else {
                        adjustedShares[i] += uint128(liquidityPool.sharesForAmount(rescaledTierRewards - tierRewards[i]));
                    }
                }
            }
        }

        return (globalIndex, adjustedShares);
    }

    function _min(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _b : _a;
    }

    function _max(uint256 _a, uint256 _b) internal pure returns (uint256) {
        return (_a > _b) ? _a : _b;
    }

    // always lose at least a tier, possibly more depending on percentage of deposit withdrawn
    function _applyUnwrapPenalty(uint256 _tokenId, uint256 _prevAmount, uint256 _burnAmount) internal {

        TokenData storage token = tokenData[_tokenId];
        uint8 prevTier = token.tier > 0 ? token.tier - 1 : 0;
        uint40 curTierPoints = token.baseTierPoints;

        // point deduction if we kick back to start of previous tier
        uint40 degradeTierPenalty = curTierPoints - tierData[prevTier].requiredTierPoints;

        // point deduction if scaled proportional to withdrawal amount
        uint256 ratio = (10000 * _burnAmount) / _prevAmount;
        uint40 scaledTierPointsPenalty = uint40((ratio * curTierPoints) / 10000);

        uint40 penalty = uint40(_max(degradeTierPenalty, scaledTierPointsPenalty));

        token.baseTierPoints -= penalty;
        token.prevPointsAccrualTimestamp = uint32(block.timestamp);
        _claimTier(_tokenId);
    }

    function _tierForPoints(uint40 _tierPoints) internal view returns (uint8) {
        uint8 tierId = 0;
        while (tierId < tierData.length && _tierPoints >= tierData[tierId].requiredTierPoints) {
            tierId++;
        }
        return tierId - 1;
    }

    function _verifyEapUserData(
        address _user,
        uint256 _ethBal,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _ethBal, _points));
        bool verified = MerkleProof.verify(_merkleProof, eapMerkleRoot, leaf);
        require(verified, "Verification failed");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    // it returns the value of a certain NFT interms of ETH amount
    function valueOf(uint256 _tokenId) public view returns (uint256) {
        TokenData memory tokenData = tokenData[_tokenId];
        TokenDeposit memory tokenDeposit = tokenDeposits[_tokenId];
        (uint96[] memory globalIndex, ) = _calculateGlobalIndex();
        uint256 amount = tokenDeposit.amounts;
        uint256 rewards = (globalIndex[tokenData.tier] - tokenData.rewardsLocalIndex) * amount / 1 ether;
        uint256 amountStakedForPoints = tokenDeposit.amountStakedForPoints;
        return amount + rewards + amountStakedForPoints;
    }

    function loyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        TokenData memory tokenData = tokenData[_tokenId];
        uint256 points = tokenData.baseLoyaltyPoints;
        uint256 pointsEarning = accruedLoyaltyPointsOf(_tokenId);
        uint256 total = _min(points + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierPointsOf(uint256 _tokenId) public view returns (uint40) {
        TokenData memory tokenData = tokenData[_tokenId];
        uint256 points = tokenData.baseTierPoints;
        uint256 pointsEarning = accruedTierPointsOf(_tokenId);
        uint256 total = _min(points + pointsEarning, type(uint40).max);
        return uint40(total);
    }

    function tierOf(uint256 _tokenId) public view returns (uint8) {
        return tokenData[_tokenId].tier;
    }
    
    function claimableTier(uint256 _tokenId) public view returns (uint8) {
        uint40 tierPoints = tierPointsOf(_tokenId);
        return _tierForPoints(tierPoints);
    }

    function accruedLoyaltyPointsOf(uint256 _tokenId) public view returns (uint40) {
        TokenData memory token = tokenData[_tokenId];
        return _membershipPointsEarning(_tokenId, token.prevPointsAccrualTimestamp, block.timestamp);
    }

    function accruedTierPointsOf(uint256 _tokenId) public view returns (uint40) {
        TokenDeposit memory tokenDeposit = tokenDeposits[_tokenId];
        if (tokenDeposit.amounts == 0 && tokenDeposit.amountStakedForPoints == 0) {
            return 0;
        } 
        TokenData memory tokenData = tokenData[_tokenId];
        uint256 tierPointsPerDay = 24; // 1 per an hour
        uint256 earnedPoints = (uint32(block.timestamp) - tokenData.prevPointsAccrualTimestamp) * tierPointsPerDay / 1 days;
        uint256 effectiveBalanceForEarningPoints = tokenDeposit.amounts + ((10000 + pointsBoostFactor) * tokenDeposit.amountStakedForPoints) / 10000;
        earnedPoints = earnedPoints * effectiveBalanceForEarningPoints / (tokenDeposit.amounts + tokenDeposit.amountStakedForPoints);
        return uint40(earnedPoints);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }


    //--------------------------------------------------------------------------------------
    //---------------------------------- NFT METADATA --------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice ERC1155 Metadata URI
    /// @param id token ID
    /// @dev https://eips.ethereum.org/EIPS/eip-1155#metadata
    function uri(uint256 id) public override view returns (string memory) {
        return _metadataURI;
    }

    /// @notice OpenSea contract-level metadata
    function contractURI() public view returns (string memory) {
        return string.concat(_metadataURI, "contract-metadata");
    }

    function setMetadataURI(string calldata _newURI) external onlyOwner {
        _metadataURI = _newURI;
    }

    /// @dev alert opensea to a metadata update
    function alertMetadataUpdate(uint256 id) public onlyOwner {
        emit MetadataUpdate(id);
    }

    /// @dev alert opensea to a metadata update
    function alertBatchMetadataUpdate(uint256 startID, uint256 endID) public onlyOwner {
        emit BatchMetadataUpdate(startID, endID);
    }


    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier isEEthStakingOpen() {
        require(liquidityPool.eEthliquidStakingOpened(), "Liquid staking functions are closed");
        _;
    }

    modifier onlyLiquidityPool() {
        require(msg.sender == address(liquidityPool), "Caller muat be the liquidity pool contract");
        _;
    }
}

