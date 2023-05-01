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

    uint256 public totalSupply;
    uint256 public totalAnmount;
    mapping (address => uint256) public _shares;
    mapping (address => uint256) public _amounts;
    mapping (address => mapping (address => uint256)) public allowances;

    struct UserData {
        uint8 tier;
        uint32 pointsSnapshot;
        uint32 pointsSnapshotTime;
        uint32 curTierPoints;
        uint32 nextTierPoints;
        uint32 lockedAmount;
        uint96 eEthRewardsLocalIndex;
    }

    mapping (address => uint256) public tiers;
    mapping (address => uint256) public pointSnapshot;
    mapping (address => uint256) public pointSnapshotTime;
    mapping (address => uint256) public curTierPoint;
    mapping (address => uint256) public nextTierPoint;
    mapping (address => uint256) public lockedAmount;
    mapping (address => uint256) public eEthRewardsLocalIndex;

    uint256[] public lockedSharesPerTier;
    uint256[] public lockedAmountPerTier;
    uint256 totalLockedAmount;

    // total score snapshot
    uint256 public genesisTimestamp;

    // points growth rate
    uint256 public pointsBoostFactor = 100; // +100% points if staking rewards are sacrificed
    uint256 public pointsBurnRateForUnWrap = 100; // 100% of the points proportional to the amount being unwraped
    uint256 public pointsGrowthRate = 1;
    uint256[] public pointGrowthRates; 
    uint256[] public pointGrowthRateUpdateTimes; 

    struct TierData {
        uint32 minimumPoints;
        uint96 potAmount;
        uint96 globalIndex;
        uint32 globalIndexTime;
        uint32 potLastHarvestTime;
        uint96 totalShares;
    }

    uint256[] public weightPerTier;
    uint256[] public eEthRewardsPotAmountPerTier;
    uint256[] public eEthRewardsGlobalIndexPerTier;
    uint256[] public eEthRewardsGlobalIndexTimePerTier;
    uint256[] public eEthRewardsPotLastHarvestTimestampPerTier;

    uint256[] public minimumPointsPerTier;
    uint256[] public totalSharesPerTier;

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
        uint256 share = liquidityPool.sharesForAmount(_amount);

        // if the user is new to meETH, add him to the tier 0
        if (pointSnapshot[msg.sender] == 0) {
            addToTier(msg.sender, 0);
        }

        // update user score
        updatePoints(msg.sender);

        // transfer eETH from user to meETH contract
        eETH.transferFrom(msg.sender, address(this), _amount);
        totalSharesPerTier[tierOf(msg.sender)] += share;

        // mint meETH to user
        _mint(msg.sender, share);
    }

    function unwrap(uint256 _amount) external {
        require(_amount > 0, "You cannot unwrap 0 meETH");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        require(_shares[msg.sender] >= share, "Not enough balance");

        // update user score
        updatePoints(msg.sender);

        // when a user unwraps meETH, a portion of their points proportional to the amount of meETH tokens being unwrapped is burned. 
        // The 'pointsBurnRateForUnWrap' variable specifies the percentage of the points to be burned.
        pointSnapshot[msg.sender] -= (pointsBurnRateForUnWrap * share * pointOf(msg.sender, block.timestamp)) / (100 * _shares[msg.sender]);
        curTierPoint[msg.sender] -= (pointsBurnRateForUnWrap * share * curTierPoint[msg.sender]) / (100 * _shares[msg.sender]);
        nextTierPoint[msg.sender] -= (pointsBurnRateForUnWrap * share * nextTierPoint[msg.sender]) / (100 * _shares[msg.sender]);
        updateTier(msg.sender);

        // burn meETH
        _burn(msg.sender, share);
        totalSharesPerTier[tierOf(msg.sender)] -= share;

        // transfer eETH from meETH contract to user
        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function tradeStakingRewardsForPoints(uint256 _amount) external {
        uint256 share = liquidityPool.sharesForAmount(_amount);
        require(_shares[msg.sender] >= share, "Not enough balance");

        updateTier(msg.sender);

        uint256 tier = tierOf(msg.sender);
        lockedSharesPerTier[tier] += share;
        lockedAmountPerTier[tier] += _amount;
        
        lockedAmount[msg.sender] += _amount;
        totalLockedAmount += _amount;
        _shares[msg.sender] -= share;
        _shares[address(this)] += share;
    }

    function untrade(uint256 _amount) external {
        require(lockedAmount[msg.sender] >= _amount, "Not enough balance locked");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        require(_shares[address(this)] >= share, "Not enough balance locked");

        updateTier(msg.sender);

        uint256 tier = tierOf(msg.sender);
        lockedSharesPerTier[tier] -= share;
        lockedAmountPerTier[tier] -= _amount;

        lockedAmount[msg.sender] -= _amount;
        totalLockedAmount -= _amount;
        _shares[msg.sender] += share;
        _shares[address(this)] -= share;
    }

    function balanceOf(address _account) public view override(IERC20Upgradeable) returns (uint256) {
        uint256 share = _shares[_account];
        uint256 boosted = getClaimableBoostedStakingRewards(_account);
        return lockedAmount[_account] + liquidityPool.amountForShare(share) + boosted;
    }

    function harvestSacrificedStakingRewards() external {
        for (uint i = 0; i < minimumPointsPerTier.length; i++) {
            updateGlobalIndex(i);
        }

        uint256 totalPoolShare = _shares[address(this)];
        uint256 totalPoolAmount = liquidityPool.amountForShare(totalPoolShare);
        uint256 amount = totalPoolAmount - totalLockedAmount;
        uint256 share = liquidityPool.sharesForAmount(amount);

        // TODO: Allocate eEth for the boosted rewards 
        //       according to the weights
        // For now, distribute them evenly
        for (uint i = 0; i < minimumPointsPerTier.length; i++) {

        }
    }

    function harvestSacrificedStakingRewards(uint256 _tier) external {
        updateGlobalIndex(_tier);

        uint256 amount = eEthRewardsNextPotAmount(_tier);
        uint256 share = liquidityPool.sharesForAmount(amount);
        eEthRewardsPotAmountPerTier[_tier] = amount;
        lockedSharesPerTier[_tier] -= share;
        totalSharesPerTier[_tier] -= share;
        _shares[address(this)] += share;
        eEthRewardsPotLastHarvestTimestampPerTier[_tier] = block.timestamp;
    }

    function updateTier(address _account) public {
        uint256 oldTier = tierOf(_account);
        uint256 newTier = claimableTier(_account);
        if (oldTier == newTier) {
            return;
        }
        updateGlobalIndex(oldTier);
        updateGlobalIndex(newTier);

        removeFromTier(_account, oldTier);
        addToTier(_account, newTier);
    }

    function removeFromTier(address _account, uint256 _tier) public {
        require(tierOf(_account) == _tier, "wrong tier");
        claimBoostedStakingRewards(_account);

        uint256 lockedAmount = lockedAmount[msg.sender];
        uint256 lockedShare = liquidityPool.sharesForAmount(lockedAmount);

        lockedSharesPerTier[_tier] -= lockedShare;
        lockedAmountPerTier[_tier] -= lockedAmount;
        totalSharesPerTier[_tier] -= _shares[_account];
    }

    function addToTier(address _account, uint256 _tier) public {
        uint256 lockedAmount = lockedAmount[msg.sender];
        uint256 lockedShare = liquidityPool.sharesForAmount(lockedAmount);

        lockedSharesPerTier[_tier] += lockedShare;
        lockedAmountPerTier[_tier] += lockedAmount;
        totalSharesPerTier[_tier] += _shares[_account];

        eEthRewardsLocalIndex[_account] = eEthRewardsGlobalIndexPerTier[_tier];
        tiers[_account] = _tier;
    }

    function updateGlobalIndex(uint256 _tier) public {
        eEthRewardsGlobalIndexPerTier[_tier] = _calculateGlobalIndex(_tier);
        eEthRewardsGlobalIndexTimePerTier[_tier] = block.timestamp;
    }

    function getClaimableBoostedStakingRewards(address _account) public view returns (uint256) {
        uint256 tier = tierOf(_account);
        uint256 globalIndex = _calculateGlobalIndex(tier);
        uint256 amount = (globalIndex - eEthRewardsLocalIndex[_account]) * _shares[_account] / 1 ether;

        return amount;
    }

    function _calculateGlobalIndex(uint256 _tier) public view returns (uint256) {
        uint256 untill;
        if (block.timestamp <= eEthRewardsPotLastHarvestTimestampPerTier[_tier] + 28 days) {
            untill = block.timestamp;
        } else {
            untill = eEthRewardsPotLastHarvestTimestampPerTier[_tier] + 28 days;
        }
        uint256 elapsedTime = untill >= eEthRewardsGlobalIndexTimePerTier[_tier] ? untill - eEthRewardsGlobalIndexTimePerTier[_tier] : 0;
        uint256 totalSharesEligibleForBoostedRewards = totalSharesPerTier[_tier] - lockedSharesPerTier[_tier];
        uint256 growth = 0;
        if (totalSharesEligibleForBoostedRewards > 0) {
            growth = 1 ether * elapsedTime * eEthRewardsPotAmountPerTier[_tier] / secondsTillNextSnapshot() / totalSharesEligibleForBoostedRewards;
        }
        uint256 globalIndex = eEthRewardsGlobalIndexPerTier[_tier] + growth;
        return globalIndex;
    }

    function claimBoostedStakingRewards(address _account) public {
        // advance the global index
        uint256 tier = tierOf(_account);
        updateGlobalIndex(tier);

        // calculate the amount of rewards
        uint256 globalIndex = _calculateGlobalIndex(tier);
        uint256 amount = (globalIndex - eEthRewardsLocalIndex[_account]) * _shares[_account] / 1 ether;

        // update the local index
        eEthRewardsLocalIndex[_account] = eEthRewardsGlobalIndexPerTier[tier];

        // transfer
        uint256 share = liquidityPool.sharesForAmount(amount);
        totalSharesPerTier[tier] += share;
        _transferShares(address(this), _account, share);
        // _mint(_account, share);
    }

    // This function updates the score of the given account based on their recent activity.
    // Specifically, it calculates the points earned by the account since their last point update,
    // and updates the account's score snapshot accordingly.
    // It also accumulates the user's points earned for the next tier, and updates their tier points snapshot accordingly.
    function updatePoints(address _account) public {
        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = currentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current and next tiers
        if (pointSnapshotTime[_account] < tierSnapshotTimestamp - 28 days) {
            curTierPoint[_account] = pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
            nextTierPoint[_account] = pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else if (pointSnapshotTime[_account] < tierSnapshotTimestamp) {
            curTierPoint[_account] = nextTierPoint[_account] + pointsEarning(_account, pointSnapshotTime[_account], tierSnapshotTimestamp);
            nextTierPoint[_account] = pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else {
            nextTierPoint[_account] += pointsEarning(_account, pointSnapshotTime[_account], block.timestamp);
        }

        // Update the user's score snapshot
        pointSnapshot[_account] = pointOf(_account, block.timestamp);
        pointSnapshotTime[_account] = block.timestamp;
    }

    // This function calculates the points earned by the account for the current tier.
    // It takes into account the account's points earned since the previous tier snapshot,
    // as well as any points earned during the current tier snapshot period.
    function getPointsEarningsDuringLastMembershipPeriod(address _account) public view returns (uint256) {
        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = currentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current tier
        if (pointSnapshotTime[_account] < tierSnapshotTimestamp - 28 days) {
            return pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
        } else if (pointSnapshotTime[_account] < tierSnapshotTimestamp) {
            return nextTierPoint[_account] + pointsEarning(_account, pointSnapshotTime[_account], tierSnapshotTimestamp);
        } else {
            return curTierPoint[_account];
        }
    }
    
    function updatePointsGrowthRate(uint256 newPointsGrowthRate) public {
        pointsGrowthRate = newPointsGrowthRate;
        pointGrowthRates.push(newPointsGrowthRate);
        pointGrowthRateUpdateTimes.push(block.timestamp);
    }

    function pointOf(address _account) public view returns (uint256) {
        return pointOf(_account, block.timestamp);
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function pointsEarning(address _account, uint256 _since, uint256 _until) public view returns (uint256) {
        uint256 earning = 0;
        uint256 checkpointTime = _since;
        uint256 share = _shares[_account];
        uint256 balance = liquidityPool.amountForShare(share);

        if (_shares[_account] == 0 && lockedAmount[_account] == 0) {
            return 0;
        }

        uint256 effectiveBalanceForEarningPoints = balance + ((100 + pointsBoostFactor) * lockedAmount[_account]) / 100;

        for (uint256 i = 0; i < pointGrowthRates.length; i++) {
            if (checkpointTime < pointGrowthRateUpdateTimes[i] && pointGrowthRateUpdateTimes[i] <= _until) {
                earning += effectiveBalanceForEarningPoints * (pointGrowthRateUpdateTimes[i] - checkpointTime) * pointGrowthRates[i];
                checkpointTime = pointGrowthRateUpdateTimes[i];
            }
        }
        if (_until > checkpointTime) {
            earning += effectiveBalanceForEarningPoints * (_until - checkpointTime) * pointsGrowthRate;
        }

        earning = earning / 1 days;

        return earning;
    }

    function tierOf(address _user) public view returns (uint256) {
        return tiers[_user];
    }

    function pointOf(address _account, uint256 timestamp) public view returns (uint256) {
        require(timestamp >= pointSnapshotTime[_account], "Invalid timestamp");
        uint256 points = pointSnapshot[_account] + pointsEarning(_account, pointSnapshotTime[_account], block.timestamp);
        return points;
    }

    function claimableTier(address _account) public view returns (uint256) {
        uint256 pointsEarned = getPointsEarningsDuringLastMembershipPeriod(_account);

        uint256 tierId = 0;
        while (tierId < minimumPointsPerTier.length && pointsEarned >= minimumPointsPerTier[tierId]) {
            tierId++;
        }
        return tierId - 1;
    }

    function addNewTier(uint256 _minimumPointsRequirement, uint256 _weight) external returns (uint256) {
        minimumPointsPerTier.push(_minimumPointsRequirement);
        totalSharesPerTier.push(0);
        eEthRewardsPotAmountPerTier.push(0);
        eEthRewardsGlobalIndexPerTier.push(0);
        eEthRewardsGlobalIndexTimePerTier.push(block.timestamp);
        eEthRewardsPotLastHarvestTimestampPerTier.push(block.timestamp);
        lockedSharesPerTier.push(0);
        lockedAmountPerTier.push(0);
        weightPerTier.push(_weight);
        return minimumPointsPerTier.length - 1;
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

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS  ---------------------------------
    //--------------------------------------------------------------------------------------

    function _mint(address _account, uint256 _share) public {
        uint256 amount = liquidityPool.amountForShare(_share);
        _amounts[_account] += amount;
        totalAmount += amount;
        _shares[_account] += _share;
        totalSupply += _share;
    }

    function _burn(address _account, uint256 _share) public {
        uint256 amount = liquidityPool.amountForShare(_share);
        _amounts[_account] -= amount;
        totalAmount +-= amount;
        _shares[_account] -= _share;
        totalSupply -= _share;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal {
        uint256 _sharesToTransfer = liquidityPool.sharesForAmount(_amount);
        _transferShares(_sender, _recipient, _sharesToTransfer);
        emit Transfer(_sender, _recipient, _amount);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transferShares(address _sender, address _recipient, uint256 _amount) internal {
        require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
        require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");
        require(_amount <= _shares[_sender], "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

        _shares[_sender] -= _amount;
        _shares[_recipient] += _amount;
    }
}