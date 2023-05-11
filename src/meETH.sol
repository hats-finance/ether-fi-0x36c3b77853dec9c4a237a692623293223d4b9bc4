// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import "./interfaces/IEETH.sol";
import "./interfaces/IMEETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IClaimReceiverPool.sol";

import "forge-std/console.sol";


contract meETH is IERC20Upgradeable, Initializable, OwnableUpgradeable, UUPSUpgradeable, IMEETH {
    IEETH public eETH;
    ILiquidityPool public liquidityPool;
    IClaimReceiverPool public claimReceiverPool;

    event MEETHBurnt(address indexed _recipient, uint256 _amount);

    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => UserDeposit) public _userDeposits;
    mapping (address => UserData) public _userData;
    uint32 public genesisTimestamp; // the timestamp when the meETH contract was deployed

    struct UserDeposit {
        uint128 amounts;
        uint128 amountStakedForPoints;
    }

    struct UserData {
        uint96 rewardsLocalIndex;
        uint32 pointsSnapshotTime;
        uint40 pointsSnapshot;
        uint40 curTierPoints;
        uint40 nextTierPoints;
        uint8  tier;
    }

    uint256 public pointsBoostFactor; // +100% points if staking rewards are sacrificed
    uint256 public pointsGrowthRate;

    struct TierDeposit {
        uint128 shares;
        uint128 amounts;        
    }

    struct TierData {
        uint96 rewardsGlobalIndex;
        uint96 amountStakedForPoints;
        uint40 minimumPoints;
        uint24 weight;
    }

    TierDeposit[] public tierDeposits;
    TierData[] public tierData;

    uint96[] public rewardsGlobalIndexPerTier;
    uint256   public rewardsGlobalIndexTime;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _eEthAddress, address _liquidityPoolAddress, address _claimReceiverPoolAddress) external initializer {
        require(_eEthAddress != address(0), "No zero addresses");
        require(_liquidityPoolAddress != address(0), "No zero addresses");
        require(_claimReceiverPoolAddress != address(0), "No zero addresses");
        
        __Ownable_init();
        __UUPSUpgradeable_init();

        eETH = IEETH(_eEthAddress);
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
        claimReceiverPool = IClaimReceiverPool(_claimReceiverPoolAddress);
        genesisTimestamp = uint32(block.timestamp);

        pointsBoostFactor = 100;
        pointsGrowthRate = 1;

        eETH.approve(address(this), type(uint256).max);
    }

    function name() public pure returns (string memory) {
        return "meETH token";
    }

    function symbol() public pure returns (string memory) {
        return "meETH";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalShares() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            sum += uint256(tierDeposits[i].shares);
        }
        return sum;
    }

    function totalSupply() public view override(IERC20Upgradeable, IMEETH) returns (uint256) {
        return liquidityPool.amountForShare(totalShares());
    }

    function wrap(uint256 _amount) external whenLiquidStakingOpen {
        require(_amount > 0, "You cannot wrap 0 eETH");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        // transfer eETH from user to meETH contract
        eETH.transferFrom(msg.sender, address(this), _amount);

        // mint meETH to user
        _mint(msg.sender, _amount);
    }

    function unwrap(uint256 _amount) public whenLiquidStakingOpen {
        require(_amount > 0, "You cannot unwrap 0 meETH");
        uint256 unwrappableBalance = balanceOf(msg.sender) - _userDeposits[msg.sender].amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        _applyUnwrapPenalty(msg.sender);

        // burn meETH
        _burn(msg.sender, _amount);

        // transfer eETH from meETH contract to user
        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function burnMeETHForETH(uint256 _amount) external {
        require(address(liquidityPool).balance >= _amount, "Not enough ETH in the liquidity pool");
        unwrap(_amount);

        liquidityPool.withdraw(msg.sender, _amount);

        emit MEETHBurnt(msg.sender, _amount);
    }

    function wrapEth(address _account, bytes32[] calldata _merkleProof) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "You cannot wrap 0 ETH");

        updatePoints(msg.sender);
        claimStakingRewards(_account);
        
        // deposit ETH to the LP
        // mint eETH to meETH
        liquidityPool.deposit{value: amount}(_account, address(this), _merkleProof);

        // mint meETH to user
        _mint(_account, amount);
    }

    function wrapEthForEap(address _account, uint40 _points, bytes32[] calldata _merkleProof) external payable onlyClaimReceiverPool {
        uint256 amount = msg.value;
        require(amount > 0, "You cannot wrap 0 ETH");

        _initializeEarlyAdopterPoolUserPoints(_account, _points);
        
        // mint eETH
        liquidityPool.deposit{value: amount}(_account, address(this), _merkleProof);

        // mint meETH to user
        _mint(_account, amount);

        _updateGlobalIndex();
        uint8 tier = tierOf(_account);
        _userData[_account].rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function stakeForPoints(uint256 _amount) external {
        require(_userDeposits[msg.sender].amounts >= _amount, "Not enough balance to stake for points");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        _stakeForPoints(msg.sender, _amount);
    }

    function unstakeForPoints(uint256 _amount) external {
        require(_userDeposits[msg.sender].amountStakedForPoints >= _amount, "Not enough balance staked");

        updatePoints(msg.sender);
        claimStakingRewards(msg.sender);

        _unstakeForPoints(msg.sender, _amount);
    }

    function balanceOf(address _account) public view override(IERC20Upgradeable, IMEETH) returns (uint256) {
        UserData storage userData = _userData[_account];
        UserDeposit storage userDeposit = _userDeposits[_account];
        uint96[] memory globalIndex = calculateGlobalIndex();

        uint256 amount = userDeposit.amounts;
        uint256 rewards = (globalIndex[userData.tier] - userData.rewardsLocalIndex) * amount / 1 ether;
        uint256 amountStakedForPoints = userDeposit.amountStakedForPoints;

        return amount + rewards + amountStakedForPoints;
    }

    function updateTier(address _account) public {
        uint8 oldTier = tierOf(_account);
        uint8 newTier = claimableTier(_account);
        if (oldTier == newTier) {
            return;
        }

        updatePoints(_account);
        claimStakingRewards(_account);

        _updateTier(_account, oldTier, newTier);
    }

    function calculateGlobalIndex() public view returns (uint96[] memory) {
        uint256 sumTierRewards = 0;
        uint256 sumWeightedTierRewards = 0;
        uint96[] memory globalIndex = new uint96[](tierDeposits.length);
        uint256[] memory weightedTierRewards = new uint256[](tierDeposits.length);

        for (uint256 i = 0; i < weightedTierRewards.length; i++) {
            uint256 tierRewards = liquidityPool.amountForShare(tierDeposits[i].shares) - tierDeposits[i].amounts;
            uint256 weightedTierReward = tierData[i].weight * tierRewards;

            weightedTierRewards[i] = weightedTierReward;
            globalIndex[i] = tierData[i].rewardsGlobalIndex;

            sumTierRewards += tierRewards;
            sumWeightedTierRewards += weightedTierReward;
        }

        if (sumWeightedTierRewards > 0) {
            for (uint256 i = 0; i < weightedTierRewards.length; i++) {
                uint256 amountsEligibleForRewards = tierDeposits[i].amounts - tierData[i].amountStakedForPoints;
                if (amountsEligibleForRewards > 0) {
                    uint256 rescaledTierRewards = weightedTierRewards[i] * sumTierRewards / sumWeightedTierRewards;
                    uint256 delta = 1 ether * rescaledTierRewards / amountsEligibleForRewards;
                    require(uint256(globalIndex[i]) + uint256(delta) <= type(uint96).max, "overflow");
                    globalIndex[i] += uint96(delta);                    
                }
            }
        }

        return globalIndex;
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
        UserData storage userData = _userData[_account];
        uint256 userPointsSnapshotTimestamp =userData.pointsSnapshotTime;
        if (userPointsSnapshotTimestamp == block.timestamp) {
            return;
        }
        if (userPointsSnapshotTimestamp == 0) {
           userData.pointsSnapshotTime = uint32(block.timestamp);
            return;
        }

        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = recentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current and next tiers
        if (userPointsSnapshotTimestamp < tierSnapshotTimestamp - 28 days) {
           userData.curTierPoints = _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else if (userPointsSnapshotTimestamp < tierSnapshotTimestamp) {
           userData.curTierPoints =userData.nextTierPoints + _pointsEarning(_account, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else {
           userData.nextTierPoints += _pointsEarning(_account, userPointsSnapshotTimestamp, block.timestamp);
        }

        // Update the user's score snapshot
       userData.pointsSnapshot = pointOf(_account);
       userData.pointsSnapshotTime = uint32(block.timestamp);
    }

    // This function calculates the points earned by the account for the current tier.
    // It takes into account the account's points earned since the previous tier snapshot,
    // as well as any points earned during the current tier snapshot period.
    function getPointsEarningsDuringLastMembershipPeriod(address _account) public view returns (uint40) {
        UserData storage userData = _userData[_account];
        uint256 userPointsSnapshotTimestamp = userData.pointsSnapshotTime;
        // Get the timestamp for the recent tier snapshot
        uint256 tierSnapshotTimestamp = recentTierSnapshotTimestamp();

        // Calculate the points earned by the account for the current tier
        if (userPointsSnapshotTimestamp < tierSnapshotTimestamp - 28 days) {
            return _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
        } else if (userPointsSnapshotTimestamp < tierSnapshotTimestamp) {
            return userData.nextTierPoints + _pointsEarning(_account, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
        } else {
            return userData.curTierPoints;
        }
    }

    function updatePointsGrowthRate(uint256 newPointsGrowthRate) public {
        pointsGrowthRate = newPointsGrowthRate;
    }

    function pointOf(address _account) public view returns (uint40) {
        UserData storage userData = _userData[_account];
        uint40 points = userData.pointsSnapshot;
        uint40 pointsEarning = _pointsEarning(_account, userData.pointsSnapshotTime, block.timestamp);

        uint40 total = 0;
        if (uint256(points) + uint256(pointsEarning) >= type(uint40).max) {
            total = type(uint40).max;
        } else {
            total = points + pointsEarning;
        }
        return total;
    }

    function pointsSnapshotTimeOf(address _account) external view returns (uint32) {
        return _userData[_account].pointsSnapshotTime;
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function _pointsEarning(address _account, uint256 _since, uint256 _until) internal view returns (uint40) {
        UserDeposit storage userDeposit = _userDeposits[_account];
        if (userDeposit.amounts == 0 && userDeposit.amountStakedForPoints == 0) {
            return 0;
        }

        uint256 elapsed = _until - _since;
        uint256 effectiveBalanceForEarningPoints = userDeposit.amounts + ((100 + pointsBoostFactor) * userDeposit.amountStakedForPoints) / 100;
        uint256 earning = effectiveBalanceForEarningPoints * elapsed * pointsGrowthRate;

        // 0.001 ether   meETH earns 1     wei   points per day
        // == 1  ether   meETH earns 1     kwei  points per day
        // == 1  Million meETH earns 1     gwei  points per day
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

        UserData storage userData = _userData[_account];
        uint256 tier = userData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - userData.rewardsLocalIndex) * _userDeposits[_account].amounts / 1 ether;
        _incrementUserDeposit(_account, amount, 0);
        userData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function claimableTier(address _account) public view returns (uint8) {
        uint40 pointsEarned = getPointsEarningsDuringLastMembershipPeriod(_account);
        return tierForPoints(pointsEarned);
    }

    function tierForPoints(uint40 _points) public view returns (uint8) {
        uint8 tierId = 0;
        while (tierId < tierDeposits.length && _points >= tierData[tierId].minimumPoints) {
            tierId++;
        }
        return tierId - 1;
    }

    function secondsTillNextSnapshot() public view returns (uint256) {
        uint256 nextSnapshotTimestampp = recentTierSnapshotTimestamp() + 4 * 7 * 24 * 3600;
        return nextSnapshotTimestampp - block.timestamp;
    }

    function recentTierSnapshotTimestamp() public view returns (uint256) {
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 i = (block.timestamp - genesisTimestamp) / monthInSeconds;
        return genesisTimestamp + i * monthInSeconds;
    }

    function transfer(address _recipient, uint256 _amount) external override(IERC20Upgradeable, IMEETH) returns (bool) {
        revert("Transfer of meETH is not allowed");
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override(IERC20Upgradeable, IMEETH) returns (bool) {
        revert("Transfer of meETH is not allowed");
    }

    function addNewTier(uint40 _minimumPointsRequirement, uint24 _weight) external onlyOwner returns (uint256) {
        require(tierDeposits.length < type(uint8).max, "Cannot add more new tier");
        // rewardsGlobalIndexPerTier.push(0);
        tierDeposits.push(TierDeposit(0, 0));
        tierData.push(TierData(0, 0, _minimumPointsRequirement, _weight));
        return tierDeposits.length - 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS  ---------------------------------
    //--------------------------------------------------------------------------------------

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "MINT_TO_THE_ZERO_ADDRESS");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(msg.sender);
        
        _incrementUserDeposit(_account, _amount, 0);
        _incrementTierDeposit(tier, _amount, share);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_userDeposits[_account].amounts >= _amount, "Not enough Balance");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(msg.sender);

        _decrementUserDeposit(_account, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }

    function _approve(address _owner, address _spender, uint256 _amount) internal {
        require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
        require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

        allowances[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _stakeForPoints(address _account, uint256 _amount) internal {
        uint256 tier = tierOf(msg.sender);
        tierData[tier].amountStakedForPoints += uint96(_amount);

        UserDeposit memory deposit = _userDeposits[_account];
        _userDeposits[_account] = UserDeposit(
            deposit.amounts - uint128(_amount),
            deposit.amountStakedForPoints + uint128(_amount)
        );
    }

    function _unstakeForPoints(address _account, uint256 _amount) internal {
        uint256 tier = tierOf(msg.sender);
        tierData[tier].amountStakedForPoints -= uint96(_amount);        

        UserDeposit memory deposit = _userDeposits[_account];
        _userDeposits[_account] = UserDeposit(
            deposit.amounts + uint128(_amount),
            deposit.amountStakedForPoints - uint128(_amount)
        );
    }

    function _incrementUserDeposit(address _account, uint256 _amount, uint256 _amountStakedForPoints) internal {
        UserDeposit memory deposit = _userDeposits[_account];
        _userDeposits[_account] = UserDeposit(
            deposit.amounts + uint128(_amount),
            deposit.amountStakedForPoints + uint128(_amountStakedForPoints)
        );
    }

    function _decrementUserDeposit(address _account, uint256 _amount, uint256 _amountStakedForPoints) internal {
        UserDeposit memory deposit = _userDeposits[_account];
        _userDeposits[_account] = UserDeposit(
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

    function _initializeEarlyAdopterPoolUserPoints(address _account, uint40 _points) internal {
        UserData storage userData = _userData[_account];
        require(userData.pointsSnapshotTime == 0, "already initialized");
        userData.pointsSnapshot += _points;
        userData.pointsSnapshotTime = uint32(block.timestamp);
        userData.tier = tierForPoints(userData.pointsSnapshot);
    }

    function _updateTier(address _account, uint8 _curTier, uint8 _newTier) internal {
        require(tierOf(_account) == _curTier, "the account does not belong to the specified tier");
        if (_curTier == _newTier) {
            return;
        }

        uint256 amount = _userDeposits[_account].amounts;
        uint256 share = liquidityPool.sharesForAmount(amount);
        uint256 amountStakedForPoints = _userDeposits[_account].amountStakedForPoints;

        tierData[_curTier].amountStakedForPoints -= uint96(amountStakedForPoints);
        _decrementTierDeposit(_curTier, amount, share);

        tierData[_newTier].amountStakedForPoints += uint96(amountStakedForPoints);
        _incrementTierDeposit(_newTier, amount, share);

        _userData[_account].rewardsLocalIndex = tierData[_newTier].rewardsGlobalIndex;
        _userData[_account].tier = _newTier;
    }

    // Degrade the user's tier to the lower one
    function _applyUnwrapPenalty(address _account) internal {
        uint8 curTier = tierOf(_account);
        uint8 newTier = (curTier >= 1) ? curTier - 1 : 0;
        _updateTier(_account, curTier, newTier);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier whenLiquidStakingOpen() {
        require(liquidityPool.eEthliquidStakingOpened(), "Liquid staking functions are closed");
        _;
    }

    //-----------------------------------  MODIFIERS  --------------------------------------

    modifier onlyLiquidityPool() {
        require(msg.sender == address(liquidityPool), "Caller muat be the liquidity pool contract");
        _;
    }

    modifier onlyClaimReceiverPool() {
        require(msg.sender == address(claimReceiverPool), "Caller muat be the claim receiver pool contract");
        _;
    }


}
