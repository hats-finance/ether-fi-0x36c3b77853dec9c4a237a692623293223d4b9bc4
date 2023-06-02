// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IeETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./MembershipNFT.sol";

contract MeETH is Initializable, OwnableUpgradeable, UUPSUpgradeable, ImeETH {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IeETH public eETH;
    ILiquidityPool public liquidityPool;
    MembershipNFT public membershipNFT;

    mapping (uint256 => TokenDeposit) public tokenDeposits;
    mapping (uint256 => TokenData) public tokenData;
    TierDeposit[] public tierDeposits;
    TierData[] public tierData;

    mapping (uint256 => uint256) public allTimeHighDepositAmount;

    mapping (address => bool) public eapDepositProcessed;
    bytes32 public eapMerkleRoot;
    uint64[] public requiredEapPointsPerEapDeposit;

    uint16 public pointsBoostFactor; // + (X / 10000) more points if staking rewards are sacrificed
    uint16 public pointsGrowthRate; // + (X / 10000) kwei points earnigs per 1 meETH per day
    uint56 public minDepositGwei;
    uint8  public maxDepositTopUpPercent;


    uint256[23] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event FundsMigrated(address indexed user, uint256 _tokenId, uint256 _amount, uint256 _eapPoints, uint40 _loyaltyPoints, uint40 _tierPoints);
    event MerkleUpdated(bytes32, bytes32);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    error DissallowZeroAddress();

    function initialize(address _eEthAddress, address _liquidityPoolAddress, address _membershipNFT) external initializer {
        if (_eEthAddress == address(0)) revert DissallowZeroAddress();
        if (_liquidityPoolAddress == address(0)) revert DissallowZeroAddress();

        __Ownable_init();
        __UUPSUpgradeable_init();

        eETH = IeETH(_eEthAddress);
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
        membershipNFT = MembershipNFT(_membershipNFT);

        pointsBoostFactor = 10000;
        pointsGrowthRate = 10000;
        minDepositGwei = (0.1 ether / 1 gwei);
        maxDepositTopUpPercent = 20;
    }

    error InvalidEAPRollover();

    /// @notice EarlyAdopterPool users can re-deposit and mint meETH claiming their points & tiers
    /// @dev The deposit amount must be greater than or equal to what they deposited into the EAP
    /// @param _amount amount of ETH to earn staking rewards.
    /// @param _amountForPoints amount of ETH to boost earnings of {loyalty, tier} points
    /// @param _snapshotEthAmount exact balance that the user has in the merkle snapshot
    /// @param _points EAP points that the user has in the merkle snapshot
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    function wrapEthForEap(
        uint256 _amount,
        uint256 _amountForPoints,
        uint256 _snapshotEthAmount,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) external payable returns (uint256) {
        if (_points == 0) revert InvalidEAPRollover();
        if (msg.value < _snapshotEthAmount) revert InvalidEAPRollover();
        if (msg.value > _snapshotEthAmount * 2) revert InvalidEAPRollover();
        if (msg.value != _amount + _amountForPoints) revert InvalidEAPRollover();
        if (eapDepositProcessed[msg.sender] == true) revert InvalidEAPRollover();

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _snapshotEthAmount, _points));
        if (!MerkleProof.verify(_merkleProof, eapMerkleRoot, leaf)) revert InvalidEAPRollover(); 

        eapDepositProcessed[msg.sender] = true;
        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);

        (uint40 loyaltyPoints, uint40 tierPoints) = convertEapPoints(_points, _snapshotEthAmount);
        uint256 tokenId = _mintMembershipNFT(msg.sender, msg.value - _amountForPoints, _amountForPoints, loyaltyPoints, tierPoints);

        emit FundsMigrated(msg.sender, tokenId, msg.value, _points, loyaltyPoints, tierPoints);
        return tokenId;
    }

    error InvalidDeposit();
    error InvalidAllocation();
    error InvalidAmount();
    error InsufficientBalance();

    /// @notice Wraps ETH into a meETH NFT.
    /// @dev This function allows users to wrap their ETH into meETH NFT.
    /// @param _amount amount of ETH to earn staking rewards.
    /// @param _amountForPoints amount of ETH to boost earnings of {loyalty, tier} points
    /// @param _merkleProof Array of hashes forming the merkle proof for the user.
    /// @return tokenId The ID of the minted meETH membership NFT.
    function wrapEth(uint256 _amount, uint256 _amountForPoints, bytes32[] calldata _merkleProof) public payable returns (uint256) {
        if (msg.value / 1 gwei < minDepositGwei) revert InvalidDeposit();
        if (msg.value != _amount + _amountForPoints) revert InvalidAllocation();

        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);
        uint256 tokenId = _mintMembershipNFT(msg.sender, msg.value - _amountForPoints, _amountForPoints, 0, 0);
        return tokenId;
    }

    /// @notice Increase your deposit tied to this NFT within the configured percentage limit.
    /// @dev Can only be done once per month
    /// @param _tokenId ID of NFT token
    /// @param _amount amount of ETH to earn staking rewards.
    /// @param _amountForPoints amount of ETH to boost earnings of {loyalty, tier} points
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    function topUpDepositWithEth(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints, bytes32[] calldata _merkleProof) public payable {
        _requireTokenOwner(_tokenId);
        _topUpDeposit(_tokenId, _amount, _amountForPoints);
        liquidityPool.deposit{value: msg.value}(msg.sender, address(this), _merkleProof);
    }


    error ExceededMaxWithdrawal();
    error ExceededMaxDeposit();
    error InsufficientLiquidity();
    error EtherSendFailed();

    /// @notice Unwraps meETH tokens for ETH.
    /// @dev This function allows users to unwrap their meETH tokens and receive ETH in return.
    /// @param _tokenId The ID of the meETH membership NFT to unwrap.
    /// @param _amount The amount of meETH tokens to unwrap.
    function unwrapForEth(uint256 _tokenId, uint256 _amount) external {
        _requireTokenOwner(_tokenId);
        if (address(liquidityPool).balance < _amount) revert InsufficientLiquidity();

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        if (!membershipNFT.isWithdrawable(_tokenId, _amount)) revert ExceededMaxWithdrawal();

        uint256 prevAmount = tokenDeposits[_tokenId].amounts;
        _updateAllTimeHighDepositOf(_tokenId);
        _withdraw(_tokenId, _amount);
        _applyUnwrapPenalty(_tokenId, prevAmount, _amount);

        liquidityPool.withdraw(address(this), _amount);
        (bool sent, ) = address(msg.sender).call{value: _amount}("");
        if (!sent) revert EtherSendFailed();
    }



    /// @notice withdraw the entire balance of this NFT and burn it
    /// @param _tokenId The ID of the meETH membership NFT to unwrap
    function withdrawAndBurnForEth(uint256 _tokenId) public {
        uint256 totalBalance = _withdrawAndBurn(_tokenId);

        liquidityPool.withdraw(address(this), totalBalance);
        (bool sent, ) = address(msg.sender).call{value: totalBalance}("");
        if (!sent) revert EtherSendFailed();
    }


    /// @notice Sacrifice the staking rewards and earn more points
    /// @dev This function allows users to stake their ETH to earn membership points faster.
    /// @param _tokenId The ID of the meETH membership NFT.
    /// @param _amount The amount of ETH which sacrifices its staking rewards to earn points faster
    function stakeForPoints(uint256 _tokenId, uint256 _amount) external {
        _requireTokenOwner(_tokenId);
        if(tokenDeposits[_tokenId].amounts < _amount) revert InsufficientBalance();

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _stakeForPoints(_tokenId, _amount);
    }

    /// @notice Unstakes ETH.
    /// @dev This function allows users to un-do 'stakeForPoints'
    /// @param _tokenId The ID of the meETH membership NFT.
    /// @param _amount The amount of ETH to unstake for staking rewards.
    function unstakeForPoints(uint256 _tokenId, uint256 _amount) external {
        _requireTokenOwner(_tokenId);
        if (tokenDeposits[_tokenId].amountStakedForPoints < _amount) revert InsufficientBalance();

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _unstakeForPoints(_tokenId, _amount);
    }

    /// @notice Claims the tier.
    /// @param _tokenId The ID of the meETH membership NFT.
    /// @dev This function allows users to claim the rewards + a new tier, if eligible.
    function claimTier(uint256 _tokenId) public {
        uint8 oldTier = tokenData[_tokenId].tier;
        uint8 newTier = membershipNFT.claimableTier(_tokenId);
        if (oldTier == newTier) {
            return;
        }

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _claimTier(_tokenId, oldTier, newTier);
    }

    /// @notice Claims the accrued membership {loyalty, tier} points.
    /// @param _tokenId The ID of the meETH membership NFT.
    function claimPoints(uint256 _tokenId) public {
        TokenData storage token = tokenData[_tokenId];
        token.baseLoyaltyPoints = membershipNFT.loyaltyPointsOf(_tokenId);
        token.baseTierPoints = membershipNFT.tierPointsOf(_tokenId);
        token.prevPointsAccrualTimestamp = uint32(block.timestamp);
    }

    /// @notice Claims the staking rewards for a specific meETH membership NFT.
    /// @dev This function allows users to claim the staking rewards earned by a specific meETH membership NFT.
    /// @param _tokenId The ID of the meETH membership NFT.
    function claimStakingRewards(uint256 _tokenId) public {
        TokenData storage tokenData = tokenData[_tokenId];
        uint256 tier = tokenData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - tokenData.rewardsLocalIndex) * tokenDeposits[_tokenId].amounts / 1 ether;
        _incrementTokenDeposit(_tokenId, amount, 0);
        tokenData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
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
        uint256 tierPoints = tierData[tierId].requiredTierPoints;
        return (uint40(loyaltyPoints), uint40(tierPoints));
    }

    function updatePointsBoostFactor(uint16 _newPointsBoostFactor) public onlyOwner {
        pointsBoostFactor = _newPointsBoostFactor;
    }

    function updatePointsGrowthRate(uint16 _newPointsGrowthRate) public onlyOwner {
        pointsGrowthRate = _newPointsGrowthRate;
    }

    /// @notice Distributes staking rewards to eligible stakers.
    /// @dev This function distributes staking rewards to eligible NFTs based on their staked tokens and membership tiers.
    function distributeStakingRewards() external onlyOwner {
        (uint96[] memory globalIndex, uint128[] memory adjustedShares) = calculateGlobalIndex();
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            uint256 amounts = liquidityPool.amountForShare(adjustedShares[i]);
            tierDeposits[i].shares = adjustedShares[i];
            tierDeposits[i].amounts = uint128(amounts);
            tierData[i].rewardsGlobalIndex = globalIndex[i];
        }
    }

    error TierLimitExceeded();
    function addNewTier(uint40 _requiredTierPoints, uint24 _weight) external onlyOwner returns (uint256) {
        if (tierDeposits.length >= type(uint8).max) revert TierLimitExceeded();
        tierDeposits.push(TierDeposit(0, 0));
        tierData.push(TierData(0, 0, _requiredTierPoints, _weight));
        return tierDeposits.length - 1;
    }

    /// @notice Sets the points for a given Ethereum address.
    /// @dev This function allows the contract owner to set the points for a specific Ethereum address.
    /// @param _tokenId The ID of the meETH membership NFT.
    /// @param _loyaltyPoints The number of loyalty points to set for the specified NFT.
    /// @param _tierPoints The number of tier points to set for the specified NFT.
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
    /// @param _value minimum deposit in wei
    function setMinDepositWei(uint56 _value) external onlyOwner {
        minDepositGwei = _value;
    }

    /// @notice Updates minimum valid deposit
    /// @param _percent integer percentage value
    function setMaxDepositTopUpPercent(uint8 _percent) external onlyOwner {
        maxDepositTopUpPercent = _percent;
    }

    /// @notice Updates the eETH address
    /// @param _eEthAddress address of the new eETH instance
    function setEETHInstance(address _eEthAddress) external onlyOwner {
        eETH = IeETH(_eEthAddress);
    }

    /// @notice Updates the liquidity pool address
    /// @param _liquidityPoolAddress address of the new LP instance
    function setLPInstance(address _liquidityPoolAddress) external onlyOwner {
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------

    /**
    * @dev Internal function to mint a new membership NFT.
    * @param to The address of the recipient of the NFT.
    * @param _amount The amount of ETH to earn the staking rewards.
    * @param _amountForPoints The amount of ETH to boost the points earnings.
    * @param _loyaltyPoints The initial loyalty points for the NFT.
    * @param _tierPoints The initial tier points for the NFT.
    * @return tokenId The unique ID of the newly minted NFT.
    */
    function _mintMembershipNFT(address to, uint256 _amount, uint256 _amountForPoints, uint40 _loyaltyPoints, uint40 _tierPoints) internal returns (uint256) {

        uint256 tokenId = membershipNFT.nextMintID();

        uint8 tier = tierForPoints(_tierPoints);
        TokenData storage tokenData = tokenData[tokenId];
        tokenData.baseLoyaltyPoints = _loyaltyPoints;
        tokenData.baseTierPoints = _tierPoints;
        tokenData.prevPointsAccrualTimestamp = uint32(block.timestamp);
        tokenData.tier = tier;
        tokenData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;

        _deposit(tokenId, _amount, _amountForPoints);
        uint256 mintedTokenId = membershipNFT.mint(to, 1);
        require(mintedTokenId == tokenId, "Invalid mint"); // shouldn't be an issue?

        return mintedTokenId;
    }

    function _deposit(uint256 _tokenId, uint256 _amount, uint256 _amountForPoints) internal {
        uint256 share = liquidityPool.sharesForAmount(_amount + _amountForPoints);
        uint256 tier = tokenData[_tokenId].tier;
        _incrementTokenDeposit(_tokenId, _amount, _amountForPoints);
        _incrementTierDeposit(tier, _amount + _amountForPoints, share);
        tierData[tier].amountStakedForPoints += uint96(_amountForPoints);
    }

    error OncePerMonth();

    function _topUpDeposit(uint256 _tokenId, uint128 _amount, uint128 _amountForPoints) internal {
        canTopUp(_tokenId, msg.value, _amount, _amountForPoints);

        claimPoints(_tokenId);
        claimStakingRewards(_tokenId);

        _deposit(_tokenId, _amount, _amountForPoints);
        tokenData[_tokenId].prevTopUpTimestamp = uint32(block.timestamp);
    }

    function _withdrawAndBurn(uint256 _tokenId) internal returns (uint256) {
        _requireTokenOwner(_tokenId);

        claimStakingRewards(_tokenId);

        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        uint256 totalBalance = deposit.amounts + deposit.amountStakedForPoints;
        _unstakeForPoints(_tokenId, deposit.amountStakedForPoints);
        _withdraw(_tokenId, totalBalance);
        membershipNFT.burn(msg.sender, _tokenId, 1);

        return totalBalance;
    }

    function _withdraw(uint256 _tokenId, uint256 _amount) internal {
        if (tokenDeposits[_tokenId].amounts < _amount) revert InsufficientBalance();
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tokenData[_tokenId].tier;
        _decrementTokenDeposit(_tokenId, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }

    function _stakeForPoints(uint256 _tokenId, uint256 _amount) internal {
        uint256 tier = tokenData[_tokenId].tier;
        tierData[tier].amountStakedForPoints += uint96(_amount);
        _incrementTokenDeposit(_tokenId, 0, _amount);
        _decrementTokenDeposit(_tokenId, _amount, 0);
    }

    function _unstakeForPoints(uint256 _tokenId, uint256 _amount) internal {
        uint256 tier = tokenData[_tokenId].tier;
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
        uint8 oldTier = tokenData[_tokenId].tier;
        uint8 newTier = membershipNFT.claimableTier(_tokenId);
        _claimTier(_tokenId, oldTier, newTier);
    }

    error UnexpectedTier();

    function _claimTier(uint256 _tokenId, uint8 _curTier, uint8 _newTier) internal {
        if (tokenData[_tokenId].tier != _curTier) revert UnexpectedTier();
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

    function _updateAllTimeHighDepositOf(uint256 _tokenId) internal returns (uint256) {
        allTimeHighDepositAmount[_tokenId] = membershipNFT.allTimeHighDepositOf(_tokenId);
    }

    error OnlyTokenOwner();
    function _requireTokenOwner(uint256 _tokenId) internal view {
        if (membershipNFT.balanceOf(msg.sender, _tokenId) != 1) revert OnlyTokenOwner();
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function membershipPointsEarning(uint256 _tokenId, uint256 _since, uint256 _until) public view returns (uint40) {
        TokenDeposit memory tokenDeposit = tokenDeposits[_tokenId];
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

    error IntegerOverflow();

    /**
    * @dev This function calculates the global index and adjusted shares for each tier used for reward distribution.
    *
    * The function performs the following steps:
    * 1. Iterates over each tier, computing rebased amounts, tier rewards, weighted tier rewards.
    * 2. Sums all the tier rewards and the weighted tier rewards.
    * 3. If there are any weighted tier rewards, it iterates over each tier to perform the following actions:
    *    a. Computes the amounts eligible for rewards.
    *    b. If there are amounts eligible for rewards, 
    *       it calculates rescaled tier rewards and updates the global index and adjusted shares for the tier.
    *
    * The rescaling of tier rewards is done based on the weight of each tier. 
    *
    * @notice This function essentially pools all the staking rewards across tiers and redistributes them propoertional to the tier weights
    * @return globalIndex A uint96 array containing the updated global index for each tier.
    * @return adjustedShares A uint128 array containing the updated shares for each tier reflecting the amount of staked ETH in the liquidity pool.
    */
    function calculateGlobalIndex() public view returns (uint96[] memory, uint128[] memory) {
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
                    if (uint256(globalIndex[i]) + uint256(delta) > type(uint96).max) revert IntegerOverflow();
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

    /// @notice Applies the unwrap penalty.
    /// @dev Always lose at least a tier, possibly more depending on percentage of deposit withdrawn
    /// @param _tokenId The ID of the meETH membership NFT.
    /// @param _prevAmount The amount of ETH that the NFT was holding
    /// @param _withdrawalAmount The amount of ETH that is being withdrawn
    function _applyUnwrapPenalty(uint256 _tokenId, uint256 _prevAmount, uint256 _withdrawalAmount) internal {
        TokenData storage token = tokenData[_tokenId];
        uint8 prevTier = token.tier > 0 ? token.tier - 1 : 0;
        uint40 curTierPoints = token.baseTierPoints;

        // point deduction if we kick back to start of previous tier
        uint40 degradeTierPenalty = curTierPoints - tierData[prevTier].requiredTierPoints;

        // point deduction if scaled proportional to withdrawal amount
        uint256 ratio = (10000 * _withdrawalAmount) / _prevAmount;
        uint40 scaledTierPointsPenalty = uint40((ratio * curTierPoints) / 10000);

        uint40 penalty = uint40(_max(degradeTierPenalty, scaledTierPointsPenalty));

        token.baseTierPoints -= penalty;
        token.prevPointsAccrualTimestamp = uint32(block.timestamp);
        _claimTier(_tokenId);
    }

    // Finds the corresponding for the tier points
    function tierForPoints(uint40 _tierPoints) public view returns (uint8) {
        uint8 tierId = 0;
        while (tierId < tierData.length && _tierPoints >= tierData[tierId].requiredTierPoints) {
            tierId++;
        }
        return tierId - 1;
    }

    function canTopUp(uint256 _tokenId, uint256 _totalAmount, uint128 _amount, uint128 _amountForPoints) public view returns (bool) {
        uint32 prevTopUpTimestamp = tokenData[_tokenId].prevTopUpTimestamp;
        TokenDeposit memory deposit = tokenDeposits[_tokenId];
        uint256 monthInSeconds = 28 days;
        uint256 maxDeposit = ((deposit.amounts + deposit.amountStakedForPoints) * maxDepositTopUpPercent) / 100;
        if (block.timestamp - uint256(prevTopUpTimestamp) < monthInSeconds) revert OncePerMonth();
        if (_totalAmount != _amount + _amountForPoints) revert InvalidAllocation();
        if (_totalAmount > maxDeposit) revert ExceededMaxDeposit();

        return true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------
    

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }
}
