// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IeETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IRegulationsManager.sol";

contract MeETH is Initializable, OwnableUpgradeable, UUPSUpgradeable, ImeETH {

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

    struct TierDeposit {
        uint128 shares;
        uint128 amounts;
    }
    TierDeposit[] public tierDeposits;

    struct TierData {
        uint96 rewardsGlobalIndex;
        uint96 amountStakedForPoints;
        uint40 requiredTierPoints;
        uint24 weight;
    }
    TierData[] public tierData;

    struct UserDeposit {
        uint128 amount;
        uint128 amountStakedForPoints;
    }
    mapping (address => UserDeposit) public _userDeposits;

    struct TokenData {
        uint96 rewardsLocalIndex;
        uint32 pointsSnapshotTime;
        uint40 pointsSnapshot;
        uint40 baseTierPoints;
        uint8  tier;

        // TODO(dave): inefficient. Will move this to separate data structure
        uint32 accrualTimestamp;
        uint128 depositAmount;
        uint128 amountStakedForPoints;
    }
    mapping (uint256 => TokenData) public _tokenData;

    // ownership tracking for all nft tokens
    // tokenID is implicit to location in array. Index 0 -> tokenID 0, Index 1 -> tokenID 1
    // TODO(dave): decide if we want to support multiple different collections
    address[] public owners;

    /// @dev base URI for all token metadata
    string private _metadataURI;


    uint256 public tierPointsPerMonth = 1000
    function setTierPointsPerMonth(uint256 amount) external onlyOwner {
        tierPointsPerMonth = amount;
    }


    // TODO(dave): calculate new gap
    uint256[23] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event FundsMigrated(address user, uint256 amount, uint256 eapPoints, uint40 loyaltyPoints);
    event MerkleUpdated(bytes32, bytes32);

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);

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

    function wrapEEth(uint256 _amount) external isEEthStakingOpen returns (uint256) {
        require(_amount > 0, "You cannot wrap 0 eETH");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        eETH.transferFrom(msg.sender, address(this), _amount);
        return _mintLoyaltyNFT(msg.sender, _amount, 0);
    }

    function wrapEth(address _account, uint256 _amount, bytes32[] calldata _merkleProof) public payable returns (uint256) {
        require(_amount > 0, "You cannot wrap 0 ETH");

        // TODO(dave): check if this reverts on failure
        liquidityPool.deposit{value: _amount}(_account, address(this), _merkleProof);
        return _mintLoyaltyNFT(msg.sender, _amount, 0);
    }

    function unwrapForEEth(uint256 tokenID, uint256 _amount) public isEEthStakingOpen {
        if (owners[tokenID] != msg.sender) revert OnlyTokenOwner();
        require(_amount > 0, "You cannot unwrap 0 meETH");

        TokenData memory token = _tokenData[tokenID];
        uint256 unwrappableBalance = token.depositAmount - token.amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        _applyWithdrawalPenalty(tokenID, _amount);

        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function unwrapForEth(uint256 tokenID, uint256 _amount) external {
        if (owners[tokenID] != msg.sender) revert OnlyTokenOwner();
        require(address(liquidityPool).balance >= _amount, "Not enough ETH in the liquidity pool");

        TokenData memory token = _tokenData[tokenID];

        // TODO(dave): the original version did not have this check for vanilla ETH. Ask if that's intentional
        uint256 unwrappableBalance = token.depositAmount - token.amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        _applyWithdrawalPenalty(tokenID, _amount);

        liquidityPool.withdraw(address(this), _amount);
        (bool sent, ) = address(msg.sender).call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /// Start here tomorrow --------------------------------------------------
    --------------------------------------------------

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


    function claimStakingRewards(address _account) public {

        UserData storage userData = _userData[_account];
        uint256 tier = userData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - userData.rewardsLocalIndex) * _userDeposits[_account].amounts / 1 ether;
        _incrementUserDeposit(_account, amount, 0);
        userData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
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


    //--------------------------------------------------------------------------------------
    //-------------------------------  INTERNAL FUNCTIONS   --------------------------------
    //--------------------------------------------------------------------------------------


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

    function _applyWithdrawalPenalty(uint256 _tokenID, uint256 _withdrawalAmount) internal {
        // TODO(dave): implement

        // pointLoss = max(number of points to kick you back to previous tier, points * percentage of deposit that withdrawal is) (edited)
        // 
        // possibly support skimming depending on discussion
        // if(less than 5% && only once per month) then no penalty
    }

    /*
    function _applyUnwrapPenaltyByDeductingPointsEarnings(address _account, uint256 _prevAmount, uint256 _burnAmount) internal {
        UserData storage userData = _userData[_account];
        userData.curTierPoints -= uint40(userData.curTierPoints * _burnAmount / _prevAmount);
        userData.nextTierPoints -= uint40(userData.nextTierPoints * _burnAmount / _prevAmount);
        _claimTier(_account);
    }
    */

    //--------------------------------------------------------------------------------------
    //-------------------------------  EARLY ADOPTER POOL ----------------------------------
    //--------------------------------------------------------------------------------------

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

        // convert eap points to loyalty points
        uint256 loyaltyPoints = uint40(_min(
            (_eapPoints * 1e14 / 1000) / 1 days / 0.001 ether,
            type(uint40.max)
        ));

        _wrapEthForEap(msg.sender, _ethAmount, loyaltyPoints, _merkleProof);
        wrapEth(msg.sender, msg.value - _ethAmount, _merkleProof);

        emit FundsMigrated(msg.sender, _ethAmount, _points, loyaltyPoints);
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

    function _wrapEthForEap(address _account, uint256 _amount, uint40 _points, bytes32[] calldata _merkleProof) internal {
        require(pointsSnapshotTimeOf(_account) == 0, "Already Deposited");

        /*
        _initializeEarlyAdopterPoolUserPoints(_account, _points, _amount);

        UserData storage userData = _userData[_account];
        require(userData.pointsSnapshotTime == 0, "already initialized");
        userData.pointsSnapshot = _points;
        userData.pointsSnapshotTime = uint32(block.timestamp);
        uint40 userPointsPerDepositAmount = calculatePointsPerDepositAmount(_points, _amount);
        userData.tier = tierForPointsPerDepositAmount(userPointsPerDepositAmount);
        */

        liquidityPool.deposit{value: _amount}(_account, address(this), _merkleProof);

        // TODO(dave): finalize mapping of existing point totals to initial tiers
        uint8 baseTierPoints = _points / 1000; // made up formula

        _mintLoyaltyNFT(_account, _amount, baseTierPoints);

        uint8 tier = tierOf(_account);
        _userData[_account].rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------------  GETTER  --------------------------------------
    //--------------------------------------------------------------------------------------

    function totalShares() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            sum += uint256(tierDeposits[i].shares);
        }
        return sum;
    }

    function balanceOf(address _account, tokenID) public view returns (uint256) {
        return owners[tokenID] == account ? 1 : 0;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  TIERS AND MEMBERSHIP  -------------------------------
    //--------------------------------------------------------------------------------------

    function claimableTier(uint256 tokenID) public view returns (uint8) {
        TokenData memory token = _tokenData[tokenID];
        uint256 tierPoints = token.baseTierPoints + accruedTierPoints(tokenID);

        return tierForPoints(tierPoints);
    }

    function accruedTierPoints(uint256 tokenID) public view returns (uint256) {
        TokenData memory token = _tokenData[tokenID];

        uint256 elapsedMonths = (block.timestamp - token.accrualTimestamp) / monthInSeconds;
        return elapsedMonths * tierPointsPerMonth;
    }

    function tierForPoints(tierPoints uint40) internal returns (uint8) {
        uint8 tierId = 0;
        while (tierId < tierData.length && tierPoints >= tierData[tierID].requiredTierPoints) {
            tierId++;
        }
        return tierId - 1;
    }

    error OnlyTokenOwner();

    function claimTier(uint256 tokenID) external {
        if (owners[tokenID] != msg.sender) revert OnlyTokenOwner();

        uint8 oldTier = tierOf(_account);
        uint8 newTier = claimableTier(_account);
        if (oldTier == newTier) {
            return;
        }

//        claimPoints(_account);
 //       claimStakingRewards(_account);

        uint256 amount = _min(_userDeposits[_account].amounts, tierDeposits[_curTier].amounts);
        uint256 share = liquidityPool.sharesForAmount(amount);
        uint256 amountStakedForPoints = _userDeposits[_account].amountStakedForPoints;

        tierData[_curTier].amountStakedForPoints -= uint96(amountStakedForPoints);
        _decrementTierDeposit(_curTier, amount, share);

        tierData[_newTier].amountStakedForPoints += uint96(amountStakedForPoints);
        _incrementTierDeposit(_newTier, amount, share);

        _userData[_account].rewardsLocalIndex = tierData[_newTier].rewardsGlobalIndex;
        _userData[_account].tier = _newTier;
    }


    function claimMembershipPoints(uint256 tokenID) external {
        if (owners[tokenID] != msg.sender) revert OnlyTokenOwner();

        TokenData storage token = _tokenData[_account];
        if (token.pointsSnapshotTime == 0) {
            userData.pointsSnapshotTime = token.depositTimestamp;
        }

       // Update the user's score snapshot
       token.pointsSnapshot += accruedMembershipPoints(tokenID, token.pointsSnapshotTime, block.timestamp);
       userData.pointsSnapshotTime = uint32(block.timestamp);
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function accruedMembershipPoints(uint256 tokenID, uint256 _since, uint256 _until) internal view returns (uint40) {
        TokenData memory token = _userDeposits[_account];
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

    function _mintLoyaltyNFT(address to, uint256 ethAmount, baseTierPoints uint8) internal returns (uint256) {

        uint256 tokenID = owners.length;
        owners.push(to);

        // XXX
        // TODO(dave): store other Token data

        emit TransferSingle(msg.sender, address(0), to, tokenID, 1);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), tokenID, amount, data) ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );

        return tokenID;
    }

    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "MINT_TO_THE_ZERO_ADDRESS");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(_account);

        _incrementUserDeposit(_account, _amount, 0);
        _incrementTierDeposit(tier, _amount, share);
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_userDeposits[_account].amounts >= _amount, "Not enough Balance");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(_account);

        _decrementUserDeposit(_account, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }


    /*
    function tierOf(address _user) public view returns (uint8) {
        return _userData[_user].tier;
    }

        function tierForPointsPerDepositAmount(uint40 _pointsPerDepositAmount) public view returns (uint8) {
-        uint8 tierId = 0;
-        while (tierId < tierDeposits.length && _pointsPerDepositAmount >= tierData[tierId].minPointsPerDepositAmount) {
-            tierId++;
-        }
-        return tierId - 1;
-    }

    */

    // TODO(dave): do I even need this. Or just return stored snapshot points?
    function pointsOf(uint256 tokenID) public view returns (uint40) {
        TokenData memory token = _tokenData[_account];
        uint40 points = token.pointsSnapshot;
        uint40 pointsEarning = _pointsEarning(token, token.pointsSnapshotTime, block.timestamp);

        return uint40(_min(uint256(points)+uint256(pointsEarning), type(uint40).max));
    }

    /*
    function pointsSnapshotTimeOf(address _account) public view returns (uint32) {
        return _userData[_account].pointsSnapshotTime;
    }
    */


    /*
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
    */


   /*

    function calculatePointsPerDepositAmount(uint40 _points, uint256 _amount) public view returns (uint40) {
        uint256 userTotalDepositScaled = _amount / (1 ether / 1000);
        uint40 userPointsPerDepositAmount;
        if (userTotalDepositScaled > 0) {
            userPointsPerDepositAmount = uint40(_points / userTotalDepositScaled); // points earned per 0.001 ether
        }
        return userPointsPerDepositAmount;
    }
    */


    /*
    function recentTierSnapshotTimestamp() public view returns (uint256) {
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 i = (block.timestamp - genesisTime) / monthInSeconds;
        return genesisTime + i * monthInSeconds;
    }
    */

    function allowance(address _owner, address _spender) external view override(IERC20Upgradeable, ImeETH) returns (uint256) {
        return allowances[_owner][_spender];
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  METADATA  -------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice ERC1155 Metadata URI
    /// @param id token ID
    /// @dev https://eips.ethereum.org/EIPS/eip-1155#metadata
    function uri(uint256 id) public view returns (string memory) {
        return _metadataURI;
    }

    /// @notice OpenSea contract-level metadata
    function contractURI() public view returns (string memory) {
        return string.concat(_metadataURI, "contract-metadata");
    }

    function setMetadataURI(string calldata _newURI) external onlyOwner {
        _metadataURI = newURI;
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
    //------------------------------------- ADMIN ------------------------------------------
    //--------------------------------------------------------------------------------------

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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

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
