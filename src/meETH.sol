// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import "./interfaces/IEETH.sol";
import "./interfaces/ILiquidityPool.sol";

import "forge-std/console.sol";


contract meETH is IERC20Upgradeable {
    // eETH contract address
    IEETH public eETH;
    ILiquidityPool public liquidityPool;

    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => UserDeposit) public _userDeposits;
    mapping (address => UserData) public _userData;

    struct UserDeposit {
        uint128 amounts;
        uint128 sacrificedAmounts;
    }

    struct UserData {
        uint96 rewardsLocalIndex;
        uint32 pointsSnapshotTime;
        uint40 pointsSnapshot;
        uint40 curTierPoints;
        uint40 nextTierPoints;
        uint8 tier;
    }


    // total score snapshot
    uint256 public genesisTimestamp;

    // points growth rate
    uint256 public pointsBoostFactor = 100; // +100% points if staking rewards are sacrificed
    uint256 public pointsBurnRateForUnWrap = 100; // 100% of the points proportional to the amount being unwraped
    uint256 public pointsGrowthRate = 1;
    uint256[] public pointGrowthRates; 
    uint256[] public pointGrowthRateUpdateTimes; 

    struct TierDeposit {
        uint128 shares;
        uint128 amounts;        
    }

    struct TierData {
        uint96 rewardsGlobalIndex;
        uint96 sacrificedAmount; // 
        uint40 minimumPoints;
        uint24 weight;
    }

    TierDeposit[] public tierDeposits;
    TierData[] public tierData;

    uint96[] public rewardsGlobalIndexPerTier;
    uint256   public rewardsGlobalIndexTime;

    constructor(address _eEthAddress, address _liquidityPoolAddress) {
        eETH = IEETH(_eEthAddress);
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
        genesisTimestamp = block.timestamp;
    }

    /**
     * @return the name of the token.
     */
    function name() public pure returns (string memory) {
        return "meETH token";
    }

    /**
     * @return the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public pure returns (string memory) {
        return "meETH";
    }

    /**
     * @return the number of decimals for getting user representation of a token amount.
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    function wrap(uint256 _amount) external {
        require(_amount > 0, "You cannot wrap 0 eETH");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        // if the user is new to meETH, add him to the tier 0
        if (_userData[msg.sender].pointsSnapshot == 0) {
            addToTier(msg.sender, 0);
        }

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        // transfer eETH from user to meETH contract
        eETH.transferFrom(msg.sender, address(this), _amount);

        // mint meETH to user
        _mint(msg.sender, _amount);
    }

    function unwrap(uint256 _amount) external {
        require(_amount > 0, "You cannot unwrap 0 meETH");
        require(_userDeposits[msg.sender].amounts >= _amount, "Not enough balance");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        degradeToLowerTier(msg.sender);

        // burn meETH
        _burn(msg.sender, _amount);

        // transfer eETH from meETH contract to user
        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function sacrificeRewardsForPoints(uint256 _amount) external {
        require(_userDeposits[msg.sender].amounts >= _amount, "Not enough balance");

        console.log("sacrificeRewardsForPoints", _amount);

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        _sacrificeUserDeposit(msg.sender, _amount);
    }

    function untrade(uint256 _amount) external {
        console.log("untrade", _amount);
        require(_userDeposits[msg.sender].sacrificedAmounts >= _amount, "Not enough balance sacrificed");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        _unSacrificeUserDeposit(msg.sender, _amount);
    }

    function balanceOf(address _account) public view override(IERC20Upgradeable) returns (uint256) {
        uint256 tier = tierOf(_account);
        uint96[] memory globalIndex = calculateGlobalIndex();

        console.log("balanceOf ...", tier, globalIndex[tier], _userData[_account].rewardsLocalIndex);

        uint256 amount = _userDeposits[_account].amounts;
        uint256 rewards = (globalIndex[tier] - _userData[_account].rewardsLocalIndex) * amount / 1 ether;
        uint256 sacrificedAmount = _userDeposits[_account].sacrificedAmounts;

        console.log("balanceOf", _userDeposits[_account].amounts, rewards, _userDeposits[_account].sacrificedAmounts);

        return amount + rewards + sacrificedAmount;
    }

    function updateTier(address _account) public {
        uint8 oldTier = tierOf(_account);
        uint8 newTier = claimableTier(_account);
        if (oldTier == newTier) {
            return;
        }

        updatePoints(_account);
        claimStakingRewards(_account);

        removeFromTier(_account, oldTier);
        addToTier(_account, newTier);
    }

    function removeFromTier(address _account, uint8 _tier) public {
        require(tierOf(_account) == _tier, "wrong tier");
        console.log("removeFromTier(..., ", _tier);

        uint256 amount = _userDeposits[_account].amounts;
        uint256 share = liquidityPool.sharesForAmount(amount);

        uint256 sacrificedAmount = _userDeposits[msg.sender].sacrificedAmounts;
        tierData[_tier].sacrificedAmount -= uint96(sacrificedAmount);
        _decrementTierDeposit(_tier, amount, share);
    }

    function addToTier(address _account, uint8 _tier) public {
        console.log("addToTier(..., ", _tier);
        uint256 sacrificedAmount = _userDeposits[msg.sender].sacrificedAmounts;
        uint256 amount = _userDeposits[_account].amounts;
        uint256 share = liquidityPool.sharesForAmount(amount);

        tierData[_tier].sacrificedAmount += uint96(sacrificedAmount);
        _incrementTierDeposit(_tier, amount, share);

        _userData[_account].rewardsLocalIndex = calculateGlobalIndex()[_tier];
        _userData[_account].tier = _tier;
    }

    function calculateGlobalIndex() public view returns (uint96[] memory) {
        uint256 sumTierRewards = 0;
        uint256 sumWeightedTierRewards = 0;
        uint96[] memory globalIndex = new uint96[](tierDeposits.length);
        uint256[] memory weightedTierRewards = new uint256[](tierDeposits.length);

        console.log("calculateGlobalIndex 1");

        // tierRewards = amountForShare(totalShares[tier]) - totalAmount[tier];
        // weightedTierRewards = weights[tier] * tierTotalRewards;
        // rescaledTierRewards = weightedTierRewards * Sum(tierRewards) / Sum(weightedTierRewards)
        // balance = amount + rescaledTierRewards * _userDeposits[_account].amounts / totalAmountsPerTier[tier];
        for (uint256 i = 0; i < weightedTierRewards.length; i++) {
            console.log("- ", liquidityPool.amountForShare(tierDeposits[i].shares), tierDeposits[i].amounts);
            uint256 tierRewards = liquidityPool.amountForShare(tierDeposits[i].shares) - tierDeposits[i].amounts;
            uint256 weightedTierReward = tierData[i].weight * tierRewards;

            weightedTierRewards[i] = weightedTierReward;
            globalIndex[i] = tierData[i].rewardsGlobalIndex;

            sumTierRewards += tierRewards;
            sumWeightedTierRewards += weightedTierReward;
        }

        console.log("calculateGlobalIndex 2");

        if (sumWeightedTierRewards > 0) {
            for (uint256 i = 0; i < weightedTierRewards.length; i++) {
                uint256 amountsEligibleForRewards = tierDeposits[i].amounts - tierData[i].sacrificedAmount;
                if (amountsEligibleForRewards > 0) {
                    uint256 rescaledTierRewards = weightedTierRewards[i] * sumTierRewards / sumWeightedTierRewards;
                    uint256 index = 1 ether * rescaledTierRewards / amountsEligibleForRewards;
                    require(uint256(globalIndex[i]) + uint256(index) <= type(uint96).max, "overflow");
                    globalIndex[i] += uint96(index);
                    console.log("- ", i, globalIndex[i]);
                    
                }
            }
        }

        console.log("calculateGlobalIndex 3");
        return globalIndex;
    }

    function degradeToLowerTier(address _account) public {
        uint8 curTier = tierOf(_account);
        uint8 newTier = (curTier >= 1) ? curTier - 1 : 0;

        if (curTier != newTier) {
            uint256 amount = _userDeposits[_account].amounts;
            uint256 share = liquidityPool.sharesForAmount(amount);
            uint256 sacrificedAmount = _userDeposits[_account].sacrificedAmounts;

            tierData[curTier].sacrificedAmount -= uint96(sacrificedAmount);
            _decrementTierDeposit(curTier, amount, share);

            tierData[newTier].sacrificedAmount += uint96(sacrificedAmount);
            _incrementTierDeposit(newTier, amount, share);

            _userData[_account].rewardsLocalIndex = tierData[newTier].rewardsGlobalIndex;
            _userData[_account].tier = newTier;
        }
    }

    function _updateGlobalIndex() internal {
        if (rewardsGlobalIndexTime == block.timestamp) {
            return;
        }

        uint96[] memory globalIndex = calculateGlobalIndex();
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            uint256 shares = uint256(tierDeposits[i].shares);
            uint256 amounts = liquidityPool.amountForShare(shares);
            tierDeposits[i].amounts = uint128(amounts);
            tierData[i].rewardsGlobalIndex = globalIndex[i];
        }
        rewardsGlobalIndexTime = block.timestamp;
    }

    // This function updates the score of the given account based on their recent activity.
    // Specifically, it calculates the points earned by the account since their last point update,
    // and updates the account's score snapshot accordingly.
    // It also accumulates the user's points earned for the next tier, and updates their tier points snapshot accordingly.
    function updatePoints(address _account) public {
        if (_userData[_account].pointsSnapshotTime == block.timestamp) {
            return;
        }

        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = currentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current and next tiers
        if (_userData[_account].pointsSnapshotTime < tierSnapshotTimestamp - 28 days) {
            _userData[_account].curTierPoints = _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
            _userData[_account].nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else if (_userData[_account].pointsSnapshotTime < tierSnapshotTimestamp) {
            _userData[_account].curTierPoints = _userData[_account].nextTierPoints + _pointsEarning(_account, _userData[_account].pointsSnapshotTime, tierSnapshotTimestamp);
            _userData[_account].nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else {
            _userData[_account].nextTierPoints += _pointsEarning(_account, _userData[_account].pointsSnapshotTime, block.timestamp);
        }

        // Update the user's score snapshot
        _userData[_account].pointsSnapshot = pointOf(_account);
        _userData[_account].pointsSnapshotTime = uint32(block.timestamp);
    }

    // This function calculates the points earned by the account for the current tier.
    // It takes into account the account's points earned since the previous tier snapshot,
    // as well as any points earned during the current tier snapshot period.
    function getPointsEarningsDuringLastMembershipPeriod(address _account) public view returns (uint256) {
        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = currentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current tier
        if (_userData[_account].pointsSnapshotTime < tierSnapshotTimestamp - 28 days) {
            return _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
        } else if (_userData[_account].pointsSnapshotTime < tierSnapshotTimestamp) {
            return _userData[_account].nextTierPoints + _pointsEarning(_account, _userData[_account].pointsSnapshotTime, tierSnapshotTimestamp);
        } else {
            return _userData[_account].curTierPoints;
        }
    }
    
    function updatePointsGrowthRate(uint256 newPointsGrowthRate) public {
        pointsGrowthRate = newPointsGrowthRate;
        pointGrowthRates.push(newPointsGrowthRate);
        pointGrowthRateUpdateTimes.push(block.timestamp);
    }

    function pointOf(address _account) public view returns (uint40) {
        uint40 points = _userData[_account].pointsSnapshot;
        uint40 pointsEarning = _pointsEarning(_account, _userData[_account].pointsSnapshotTime, block.timestamp);
        uint40 total = 0;
        if (uint256(points) + uint256(pointsEarning) >= type(uint40).max) {
            total = type(uint40).max;
        } else {
            total = points + pointsEarning;
        }
        return total;
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function _pointsEarning(address _account, uint256 _since, uint256 _until) internal view returns (uint40) {
        uint256 earning = 0;
        uint256 checkpointTime = _since;
        uint256 balance = _userDeposits[_account].amounts;

        if (balance == 0 && _userDeposits[_account].sacrificedAmounts == 0) {
            return 0;
        }

        uint256 effectiveBalanceForEarningPoints = balance + ((100 + pointsBoostFactor) * _userDeposits[_account].sacrificedAmounts) / 100;

        for (uint256 i = 0; i < pointGrowthRates.length; i++) {
            if (checkpointTime < pointGrowthRateUpdateTimes[i] && pointGrowthRateUpdateTimes[i] <= _until) {
                earning += effectiveBalanceForEarningPoints * (pointGrowthRateUpdateTimes[i] - checkpointTime) * pointGrowthRates[i];
                checkpointTime = pointGrowthRateUpdateTimes[i];
            }
        }
        if (_until > checkpointTime) {
            earning += effectiveBalanceForEarningPoints * (_until - checkpointTime) * pointsGrowthRate;
        }

        // 0.001 ether   meETH earns 1     wei   point per day
        // == 1  ether   meETH earns 1     kwei  point per day
        // == 1  Million meETH earns 1     gwei  point per day
        earning = (earning / 1 days) / 0.001 ether;

        // type(uint40).max == 2^40 - 1 ~= 4 * (10 ** 12) == 1000 gwei
        // - A user with 1 Million meETH can earn points for 1000 days
        if (earning >= type(uint40).max) {
            earning = type(uint40).max;
        }

        return uint40(earning);
    }

    function tierOf(address _user) public view returns (uint8) {
        return _userData[_user].tier;
    }

    function claimStakingRewards(address _account) public {
        _updateGlobalIndex();

        uint256 tier = tierOf(_account);
        uint256 amount = (tierData[tier].rewardsGlobalIndex - _userData[_account].rewardsLocalIndex) * _userDeposits[_account].amounts / 1 ether;

        console.log("claimStakingRewards ...", tierData[tier].rewardsGlobalIndex, _userData[_account].rewardsLocalIndex, amount);

        _incrementUserDeposit(_account, amount, 0);
        _userData[_account].rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function claimableTier(address _account) public view returns (uint8) {
        uint256 pointsEarned = getPointsEarningsDuringLastMembershipPeriod(_account);

        uint8 tierId = 0;
        while (tierId < tierDeposits.length && pointsEarned >= tierData[tierId].minimumPoints) {
            tierId++;
        }
        return tierId - 1;
    }

    function addNewTier(uint40 _minimumPointsRequirement, uint24 _weight) external returns (uint256) {
        require(tierDeposits.length < type(uint8).max, "Cannot add more new tier");
        // rewardsGlobalIndexPerTier.push(0);
        tierDeposits.push(TierDeposit(0, 0));
        tierData.push(TierData(0, 0, _minimumPointsRequirement, _weight));
        return tierDeposits.length - 1;
    }

    function secondsTillNextSnapshot() public view returns (uint256) {
        uint256 nextSnapshotTimestampp = currentTierSnapshotTimestamp() + 4 * 7 * 24 * 3600;
        return nextSnapshotTimestampp - block.timestamp;
    }

    function currentTierSnapshotTimestamp() public view returns (uint256) {
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 i = (block.timestamp - genesisTimestamp) / monthInSeconds;
        return genesisTimestamp + i * monthInSeconds;
    } 

    function transfer(address _recipient, uint256 _amount) external override(IERC20Upgradeable) returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override(IERC20Upgradeable) returns (bool) {
        uint256 currentAllowance = allowances[_sender][msg.sender];
        require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

        _transfer(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, currentAllowance - _amount);
        return true;
    }

    function totalShares() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            sum += uint256(tierDeposits[i].shares);
        }
        return sum;
    }

    function totalSupply() public view returns (uint256) {
        return liquidityPool.amountForShare(totalShares());
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS  ---------------------------------
    //--------------------------------------------------------------------------------------

    function _mint(address _account, uint256 _amount) public {
        require(_account != address(0), "MINT_TO_THE_ZERO_ADDRESS");
        console.log("_mint", _amount);
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(msg.sender);
        
        _incrementUserDeposit(_account, _amount, 0);
        _incrementTierDeposit(tier, _amount, share);
    }

    function _burn(address _account, uint256 _amount) public {
        require(_userDeposits[_account].amounts >= _amount, "Not enough Balance");
        console.log("_burn", _amount);
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(msg.sender);

        _decrementUserDeposit(_account, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        require(_amount <= _userDeposits[_sender].amounts, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        _decrementUserDeposit(_sender, _amount, 0);
        _incrementUserDeposit(_recipient, _amount, 0);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _sacrificeUserDeposit(address _account, uint256 _amount) internal {
        uint256 tier = tierOf(msg.sender);
        tierData[tier].sacrificedAmount += uint96(_amount);        
        _userDeposits[_account].sacrificedAmounts += uint128(_amount);
        _userDeposits[_account].amounts -= uint128(_amount);
    }

    function _unSacrificeUserDeposit(address _account, uint256 _amount) internal {
        uint256 tier = tierOf(msg.sender);
        tierData[tier].sacrificedAmount -= uint96(_amount);        
        _userDeposits[_account].sacrificedAmounts -= uint128(_amount);
        _userDeposits[_account].amounts += uint128(_amount);
    }

    function _incrementUserDeposit(address _account, uint256 _amount, uint256 _sacrificedAmounts) internal {
        _userDeposits[_account].amounts += uint128(_amount);
        _userDeposits[_account].sacrificedAmounts += uint128(_sacrificedAmounts);
    }

    function _decrementUserDeposit(address _account, uint256 _amount, uint256 _sacrificedAmounts) internal {
        _userDeposits[_account].amounts -= uint128(_amount);
        _userDeposits[_account].sacrificedAmounts -= uint128(_sacrificedAmounts);
    }

    function _incrementTierDeposit(uint256 _tier, uint256 _amount, uint256 _share) internal {
        tierDeposits[_tier].shares += uint128(_share);
        tierDeposits[_tier].amounts += uint128(_amount);
    }

    function _decrementTierDeposit(uint256 _tier, uint256 _amount, uint256 _share) internal {
        tierDeposits[_tier].shares -= uint128(_share);
        tierDeposits[_tier].amounts -= uint128(_amount);
    }
}