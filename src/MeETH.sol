// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IeETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IRegulationsManager.sol";

contract MeETH is IERC20Upgradeable, Initializable, OwnableUpgradeable, UUPSUpgradeable, ImeETH {

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    IeETH public eETH;
    ILiquidityPool public liquidityPool;
    IRegulationsManager public regulationsManager;

    bytes32 public merkleRoot;

    uint32 public genesisTime; // the timestamp when the meETH contract was deployed
    uint16 public pointsBoostFactor; // + (X / 10000) more points if staking rewards are sacrificed
    uint16 public pointsGrowthRate; // + (X / 10000) kwei points earnigs per 1 meETH per day

    mapping (address => mapping (address => uint256)) public allowances;
    mapping (address => UserDeposit) public _userDeposits;
    mapping (address => UserData) public _userData;

    TierDeposit[] public tierDeposits;
    TierData[] public tierData;
    uint256[23] __gap;
    
    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event FundsMigrated(address user, uint256 amount, uint256 eapPoints, uint40 loyaltyPoints);
    event MerkleUpdated(bytes32, bytes32);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function initialize(address _eEthAddress, address _liquidityPoolAddress, address _regulationsManager) external initializer {
        require(_eEthAddress != address(0), "No zero addresses");
        require(_liquidityPoolAddress != address(0), "No zero addresses");
        require(_regulationsManager != address(0), "No zero addresses");
        
        __Ownable_init();
        __UUPSUpgradeable_init();

        eETH = IeETH(_eEthAddress);
        liquidityPool = ILiquidityPool(_liquidityPoolAddress);
        regulationsManager = IRegulationsManager(_regulationsManager);

        genesisTime = uint32(block.timestamp);

        pointsBoostFactor = 10000;
        pointsGrowthRate = 10000;
    }

    /// @notice EarlyAdopterPool users can re-deposit and mint meETH claiming their points & tiers
    /// @dev The deposit amount must be the same as what they deposited into the EAP
    /// @param _points points of the user
    /// @param _ethAmount minimum balance of the user
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    function eapDeposit(
        uint256 _ethAmount,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) external payable {
        require(_points > 0, "You don't have any points to claim");
        require(regulationsManager.isEligible(regulationsManager.whitelistVersion(), msg.sender), "User is not whitelisted");
        require(msg.value >= _ethAmount, "Invalid deposit amount");
        _verifyEapUserData(msg.sender, _ethAmount, _points, _merkleProof);

        uint40 loyaltyPoints = convertEapPointsToLoyaltyPoints(_points);

        wrapEthForEap(msg.sender, _ethAmount, loyaltyPoints, _merkleProof);
        wrapEth(msg.sender, msg.value - _ethAmount, _merkleProof);

        emit FundsMigrated(msg.sender, _ethAmount, _points, loyaltyPoints);
    }

    function wrapEEth(uint256 _amount) external isEEthStakingOpen {
        require(_amount > 0, "You cannot wrap 0 eETH");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        claimPoints(msg.sender);
        claimStakingRewards(msg.sender);

        eETH.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, _amount);
    }

    function wrapEth(address _account, uint256 _amount, bytes32[] calldata _merkleProof) public payable {
        require(_amount > 0, "You cannot wrap 0 ETH");

        claimPoints(_account);
        claimStakingRewards(_account);

        liquidityPool.deposit{value: _amount}(_account, address(this), _merkleProof);
        _mint(_account, _amount);
    }

    function wrapEthForEap(address _account, uint256 _amount, uint40 _points, bytes32[] calldata _merkleProof) public {
        require(pointsSnapshotTimeOf(_account) == 0, "Already Deposited");

        _initializeEarlyAdopterPoolUserPoints(_account, _points, _amount);
        
        liquidityPool.deposit{value: _amount}(_account, address(this), _merkleProof);
        _mint(_account, _amount);
        _updateGlobalIndex();

        uint8 tier = tierOf(_account);
        _userData[_account].rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function unwrapForEEth(uint256 _amount) public isEEthStakingOpen {
        require(_amount > 0, "You cannot unwrap 0 meETH");
        uint256 unwrappableBalance = balanceOf(msg.sender) - _userDeposits[msg.sender].amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        claimPoints(msg.sender);
        claimStakingRewards(msg.sender);

        _applyUnwrapPenalty(msg.sender);
        _burn(msg.sender, _amount);

        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function unwrapForEth(uint256 _amount) external {
        require(address(liquidityPool).balance >= _amount, "Not enough ETH in the liquidity pool");

        claimPoints(msg.sender);
        claimStakingRewards(msg.sender);

        _applyUnwrapPenalty(msg.sender);
        _burn(msg.sender, _amount);

        liquidityPool.withdraw(address(this), _amount);
        (bool sent, ) = address(msg.sender).call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function stakeForPoints(uint256 _amount) external {
        require(_userDeposits[msg.sender].amounts >= _amount, "Not enough balance to stake for points");

        claimPoints(msg.sender);
        claimStakingRewards(msg.sender);

        _stakeForPoints(msg.sender, _amount);
    }

    function unstakeForPoints(uint256 _amount) external {
        require(_userDeposits[msg.sender].amountStakedForPoints >= _amount, "Not enough balance staked");

        claimPoints(msg.sender);
        claimStakingRewards(msg.sender);

        _unstakeForPoints(msg.sender, _amount);
    }

    function claimTier(address _account) public {
        uint8 oldTier = tierOf(_account);
        uint8 newTier = claimableTier(_account);
        if (oldTier == newTier) {
            return;
        }

        claimPoints(_account);
        claimStakingRewards(_account);

        _claimTier(_account, oldTier, newTier);
    }

    // This function updates the score of the given account based on their recent activity.
    // Specifically, it calculates the points earned by the account since their last point update,
    // and updates the account's score snapshot accordingly.
    // It also accumulates the user's points earned for the next tier, and updates their tier points snapshot accordingly.
    function claimPoints(address _account) public {
        UserData storage userData = _userData[_account];
        uint256 userPointsSnapshotTimestamp = userData.pointsSnapshotTime;
        if (userPointsSnapshotTimestamp == block.timestamp) {
            return;
        }
        if (userPointsSnapshotTimestamp == 0) {
            userData.pointsSnapshotTime = uint32(block.timestamp);
            return;
        }

        // Get the timestamp for the current tier snapshot
        uint256 tierSnapshotTimestamp = recentTierSnapshotTimestamp();
        int256 timeBetweenSnapshots = int256(tierSnapshotTimestamp) - int256(userPointsSnapshotTimestamp);

        // Calculate the points earned by the account for the current and next tiers
        if (timeBetweenSnapshots > 28 days) {
           userData.curTierPoints = _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else if (timeBetweenSnapshots > 0) {
           userData.curTierPoints = userData.nextTierPoints + _pointsEarning(_account, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(_account, tierSnapshotTimestamp, block.timestamp);
        } else {
           userData.nextTierPoints += _pointsEarning(_account, userPointsSnapshotTimestamp, block.timestamp);
        }

        // Update the user's score snapshot
       userData.pointsSnapshot = pointsOf(_account);
       userData.pointsSnapshotTime = uint32(block.timestamp);
    }

    function claimStakingRewards(address _account) public {
        _updateGlobalIndex();

        UserData storage userData = _userData[_account];
        uint256 tier = userData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - userData.rewardsLocalIndex) * _userDeposits[_account].amounts / 1 ether;
        _incrementUserDeposit(_account, amount, 0);
        userData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function convertEapPointsToLoyaltyPoints(uint256 _eapPoints) public view returns (uint40) {
        uint256 points = (_eapPoints * 1e14 / 1000) / 1 days / 0.001 ether;
        if (points >= type(uint40).max) {
            points = type(uint40).max;
        }
        return uint40(points);
    }

    function transfer(address _recipient, uint256 _amount) external override(IERC20Upgradeable) returns (bool) {
        revert("Transfer of meETH is not allowed");
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external override(IERC20Upgradeable) returns (bool) {
        revert("Transfer of meETH is not allowed");
    }

    function updatePointsBoostFactor(uint16 _newPointsBoostFactor) public onlyOwner {
        pointsBoostFactor = _newPointsBoostFactor;
    }

    function updatePointsGrowthRate(uint16 _newPointsGrowthRate) public onlyOwner {
        pointsGrowthRate = _newPointsGrowthRate;
    }

    function addNewTier(uint40 _minPointsPerDepositAmount, uint24 _weight) external onlyOwner returns (uint256) {
        require(tierDeposits.length < type(uint8).max, "Cannot add more new tier");
        tierDeposits.push(TierDeposit(0, 0));
        tierData.push(TierData(0, 0, _minPointsPerDepositAmount, _weight));
        return tierDeposits.length - 1;
    }

    /// @notice Updates the merkle root
    /// @param _newMerkle new merkle root used to verify the EAP user data (deposits, points)
    function updateMerkleRoot(bytes32 _newMerkle) external onlyOwner {
        bytes32 oldMerkle = merkleRoot;
        merkleRoot = _newMerkle;
        emit MerkleUpdated(oldMerkle, _newMerkle);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
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

    function _initializeEarlyAdopterPoolUserPoints(address _account, uint40 _points, uint256 _amount) internal {
        UserData storage userData = _userData[_account];
        require(userData.pointsSnapshotTime == 0, "already initialized");
        userData.pointsSnapshot = _points;
        userData.pointsSnapshotTime = uint32(block.timestamp);
        uint40 userPointsPerDepositAmount = calculatePointsPerDepositAmount(_points, _amount);
        userData.tier = tierForPointsPerDepositAmount(userPointsPerDepositAmount);
    }

    function _claimTier(address _account, uint8 _curTier, uint8 _newTier) internal {
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

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function _pointsEarning(address _account, uint256 _since, uint256 _until) internal view returns (uint40) {
        UserDeposit storage userDeposit = _userDeposits[_account];
        if (userDeposit.amounts == 0 && userDeposit.amountStakedForPoints == 0) {
            return 0;
        }

        uint256 elapsed = _until - _since;
        uint256 effectiveBalanceForEarningPoints = userDeposit.amounts + ((10000 + pointsBoostFactor) * userDeposit.amountStakedForPoints) / 10000;
        uint256 earning = effectiveBalanceForEarningPoints * elapsed * pointsGrowthRate / 10000;

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

    function _updateGlobalIndex() internal {
        uint96[] memory globalIndex = _calculateGlobalIndex();
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            uint256 shares = uint256(tierDeposits[i].shares);
            uint256 amounts = liquidityPool.amountForShare(shares);
            tierDeposits[i].amounts = uint128(amounts);
            tierData[i].rewardsGlobalIndex = globalIndex[i];
        }
    }

    function _calculateGlobalIndex() internal view returns (uint96[] memory) {
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

    // Degrade the user's tier to the lower one
    function _applyUnwrapPenalty(address _account) internal {
        uint8 curTier = tierOf(_account);
        uint8 newTier = (curTier >= 1) ? curTier - 1 : 0;
        _claimTier(_account, curTier, newTier);
    }

    function _verifyEapUserData(
        address _user,
        uint256 _ethBal,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _ethBal, _points));
        bool verified = MerkleProof.verify(_merkleProof, merkleRoot, leaf);
        require(verified, "Verification failed");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function name() public pure returns (string memory) { return "meETH token"; }
    function symbol() public pure returns (string memory) { return "meETH"; }
    function decimals() public pure returns (uint8) { return 18; }

    function totalShares() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            sum += uint256(tierDeposits[i].shares);
        }
        return sum;
    }

    function totalSupply() public view override(IERC20Upgradeable, ImeETH) returns (uint256) {
        return liquidityPool.amountForShare(totalShares());
    }

    function balanceOf(address _account) public view override(IERC20Upgradeable, ImeETH) returns (uint256) {
        UserData storage userData = _userData[_account];
        UserDeposit storage userDeposit = _userDeposits[_account];
        uint96[] memory globalIndex = _calculateGlobalIndex();

        uint256 amount = userDeposit.amounts;
        uint256 rewards = (globalIndex[userData.tier] - userData.rewardsLocalIndex) * amount / 1 ether;
        uint256 amountStakedForPoints = userDeposit.amountStakedForPoints;

        return amount + rewards + amountStakedForPoints;
    }

    function pointsOf(address _account) public view returns (uint40) {
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

    function pointsSnapshotTimeOf(address _account) public view returns (uint32) {
        return _userData[_account].pointsSnapshotTime;
    }

    function tierOf(address _user) public view returns (uint8) {
        return _userData[_user].tier;
    }

    // This function calculates the points earned by the account for the current tier.
    // It takes into account the account's points earned since the previous tier snapshot,
    // as well as any points earned during the current tier snapshot period.
    function getPointsEarningsDuringLastMembershipPeriod(address _account) public view returns (uint40) {
        UserData storage userData = _userData[_account];
        uint256 userPointsSnapshotTimestamp = userData.pointsSnapshotTime;
        // Get the timestamp for the recent tier snapshot
        uint256 tierSnapshotTimestamp = recentTierSnapshotTimestamp();
        int256 timeBetweenSnapshots = int256(tierSnapshotTimestamp) - int256(userPointsSnapshotTimestamp);

        // Calculate the points earned by the account for the current tier
        if (timeBetweenSnapshots > 28 days) {
            return _pointsEarning(_account, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
        } else if (timeBetweenSnapshots > 0) {
            return userData.nextTierPoints + _pointsEarning(_account, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
        } else {
            return userData.curTierPoints;
        }
    }

    function claimableTier(address _account) public view returns (uint8) {
        UserDeposit memory deposit = _userDeposits[_account];
        uint256 userTotalDeposit = uint256(deposit.amounts + deposit.amountStakedForPoints);
        uint40 pointsEarned = getPointsEarningsDuringLastMembershipPeriod(_account);
        uint40 userPointsPerDepositAmount = calculatePointsPerDepositAmount(pointsEarned, userTotalDeposit);
        return tierForPointsPerDepositAmount(userPointsPerDepositAmount);
    }

    function tierForPointsPerDepositAmount(uint40 _pointsPerDepositAmount) public view returns (uint8) {
        uint8 tierId = 0;
        while (tierId < tierDeposits.length && _pointsPerDepositAmount >= tierData[tierId].minPointsPerDepositAmount) {
            tierId++;
        }
        return tierId - 1;
    }

    function calculatePointsPerDepositAmount(uint40 _points, uint256 _amount) public view returns (uint40) {
        uint256 userTotalDepositScaled = _amount / (1 ether / 1000);
        uint40 userPointsPerDepositAmount = uint40(_points / userTotalDepositScaled); // points earned per 0.001 ether
        return userPointsPerDepositAmount;
    }

    function recentTierSnapshotTimestamp() public view returns (uint256) {
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 i = (block.timestamp - genesisTime) / monthInSeconds;
        return genesisTime + i * monthInSeconds;
    }

    function allowance(address _owner, address _spender) external view override(IERC20Upgradeable, ImeETH) returns (uint256) {
        return allowances[_owner][_spender];
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
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
