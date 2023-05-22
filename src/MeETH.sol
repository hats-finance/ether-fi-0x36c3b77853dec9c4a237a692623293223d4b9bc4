// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "solmate/tokens/ERC1155.sol";

import "./interfaces/IeETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IRegulationsManager.sol";

contract MeETH is ERC1155, Initializable, OwnableUpgradeable, UUPSUpgradeable, ImeETH {

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
    mapping (uint256 => UserDeposit) public _userDeposits;
    mapping (uint256 => UserData) public _userData;

    uint256 nextMintID = 0;

    /// @dev base URI for all token metadata
    string private _metadataURI;


    TierDeposit[] public tierDeposits;
    TierData[] public tierData;
    uint256[23] __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event FundsMigrated(address indexed user, uint256 amount, uint256 eapPoints, uint40 loyaltyPoints);
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

    // TODO(dave): the same user can probably do this multiple times?
    // But we also want them to keep doubling their deposit?
    // probably want some admin function to turn off migration

    /// @notice EarlyAdopterPool users can re-deposit and mint meETH claiming their points & tiers
    /// @dev The deposit amount must be greater than or equal to what they deposited into the EAP
    /// @param _points points of the user
    /// @param _ethAmount exact balance user has in the merkle snapshot
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


        uint256 mintedTokenID = wrapEth(msg.value - _ethAmount, _merkleProof);
        _initializeEarlyAdopterPoolUserPoints(mintedTokenID, loyaltyPoints, msg.value);

        uint8 tier = tierOf(mintedTokenID);
        _userData[mintedTokenID].rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;

        emit FundsMigrated(msg.sender, _ethAmount, _points, loyaltyPoints);
    }

    function wrapEEth(uint256 _amount) external isEEthStakingOpen returns (uint256) {
        require(_amount > 0, "You cannot wrap 0 eETH");
        require(eETH.balanceOf(msg.sender) >= _amount, "Not enough balance");

        uint256 tokenID = _mintLoyaltyNFT(msg.sender);
        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        eETH.transferFrom(msg.sender, address(this), _amount);
        _mint(tokenID, _amount);

        return tokenID;
    }

    function wrapEth(uint256 _amount, bytes32[] calldata _merkleProof) public payable returns (uint256) {
        require(_amount > 0, "You cannot wrap 0 ETH");

        uint256 tokenID = _mintLoyaltyNFT(msg.sender);
        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        liquidityPool.deposit{value: _amount}(msg.sender, address(this), _merkleProof);
        _mint(tokenID, _amount);
        _claimTier(tokenID);

        return tokenID;
    }

    error OnlyTokenOwner();

    function unwrapForEEth(uint256 tokenID, uint256 _amount) public isEEthStakingOpen {
        require(balanceOf[msg.sender][tokenID] == 1, "Only token owner");
        require(_amount > 0, "You cannot unwrap 0 meETH");
        UserDeposit memory deposit = _userDeposits[tokenID];
        uint256 unwrappableBalance = deposit.amounts - deposit.amountStakedForPoints;
        require(unwrappableBalance >= _amount, "Not enough balance to unwrap");

        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        uint256 prevAmount = _userDeposits[tokenID].amounts;
        _burn(tokenID, _amount);
        _applyUnwrapPenaltyByDeductingPointsEarnings(tokenID, prevAmount, _amount);

        eETH.transferFrom(address(this), msg.sender, _amount);
    }

    function unwrapForEth(uint256 tokenID, uint256 _amount) external {
        require(balanceOf[msg.sender][tokenID] == 1, "Only token owner");
        require(address(liquidityPool).balance >= _amount, "Not enough ETH in the liquidity pool");

        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        uint256 prevAmount = _userDeposits[tokenID].amounts;
        _burn(tokenID, _amount);
        _applyUnwrapPenaltyByDeductingPointsEarnings(tokenID, prevAmount, _amount);

        liquidityPool.withdraw(address(this), _amount);
        (bool sent, ) = address(msg.sender).call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    function stakeForPoints(uint256 tokenID, uint256 _amount) external {
        require(balanceOf[msg.sender][tokenID] == 1, "Only token owner");
        require(_userDeposits[tokenID].amounts >= _amount, "Not enough balance to stake for points");

        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        _stakeForPoints(tokenID, _amount);
    }

    function unstakeForPoints(uint256 tokenID, uint256 _amount) external {
        require(balanceOf[msg.sender][tokenID] == 1, "Only token owner");
        require(_userDeposits[tokenID].amountStakedForPoints >= _amount, "Not enough balance staked");

        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        _unstakeForPoints(tokenID, _amount);
    }

    function claimTier(uint256 tokenID, address _account) public {
        uint8 oldTier = tierOf(tokenID);
        uint8 newTier = claimableTier(tokenID);
        if (oldTier == newTier) {
            return;
        }

        claimPoints(tokenID);
        claimStakingRewards(tokenID);

        _claimTier(tokenID, oldTier, newTier);
    }

    // This function updates the score of the given account based on their recent activity.
    // Specifically, it calculates the points earned by the account since their last point update,
    // and updates the account's score snapshot accordingly.
    // It also accumulates the user's points earned for the next tier, and updates their tier points snapshot accordingly.
    function claimPoints(uint256 tokenID) public {
        UserData storage userData = _userData[tokenID];
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
           userData.curTierPoints = _pointsEarning(tokenID, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(tokenID, tierSnapshotTimestamp, block.timestamp);
        } else if (timeBetweenSnapshots > 0) {
           userData.curTierPoints = userData.nextTierPoints + _pointsEarning(tokenID, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
           userData.nextTierPoints = _pointsEarning(tokenID, tierSnapshotTimestamp, block.timestamp);
        } else {
           userData.nextTierPoints += _pointsEarning(tokenID, userPointsSnapshotTimestamp, block.timestamp);
        }

        // Update the user's score snapshot
       userData.pointsSnapshot = pointsOf(tokenID);
       userData.pointsSnapshotTime = uint32(block.timestamp);
    }

    function claimStakingRewards(uint256 tokenID) public {
        UserData storage userData = _userData[tokenID];
        uint256 tier = userData.tier;
        uint256 amount = (tierData[tier].rewardsGlobalIndex - userData.rewardsLocalIndex) * _userDeposits[tokenID].amounts / 1 ether;
        _incrementUserDeposit(tokenID, amount, 0);
        userData.rewardsLocalIndex = tierData[tier].rewardsGlobalIndex;
    }

    function convertEapPointsToLoyaltyPoints(uint256 _eapPoints) public view returns (uint40) {
        uint256 points = (_eapPoints * 1e14 / 1000) / 1 days / 0.001 ether;
        if (points >= type(uint40).max) {
            points = type(uint40).max;
        }
        return uint40(points);
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

    function _mintLoyaltyNFT(address to) internal returns (uint256) {

        uint256 tokenID = nextMintID++;
        balanceOf[to][tokenID] = 1;

        emit TransferSingle(msg.sender, address(0), to, tokenID, 1);

        require(
            to.code.length == 0
                ? to != address(0)
                : ERC1155TokenReceiver(to).onERC1155Received(msg.sender, address(0), tokenID, 1, "") ==
                    ERC1155TokenReceiver.onERC1155Received.selector,
            "UNSAFE_RECIPIENT"
        );

        return tokenID;
    }

    function _mint(uint256 tokenID, uint256 _amount) internal {
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(tokenID);

        _incrementUserDeposit(tokenID, _amount, 0);
        _incrementTierDeposit(tier, _amount, share);
    }

    function _burn(uint256 tokenID, uint256 _amount) internal {
        require(_userDeposits[tokenID].amounts >= _amount, "Not enough Balance");
        uint256 share = liquidityPool.sharesForAmount(_amount);
        uint256 tier = tierOf(tokenID);

        _decrementUserDeposit(tokenID, _amount, 0);
        _decrementTierDeposit(tier, _amount, share);
    }

    function _stakeForPoints(uint256 tokenID, uint256 _amount) internal {
        uint256 tier = tierOf(tokenID);
        tierData[tier].amountStakedForPoints += uint96(_amount);

        UserDeposit memory deposit = _userDeposits[tokenID];
        _userDeposits[tokenID] = UserDeposit(
            deposit.amounts - uint128(_amount),
            deposit.amountStakedForPoints + uint128(_amount)
        );
    }

    function _unstakeForPoints(uint256 tokenID, uint256 _amount) internal {
        uint256 tier = tierOf(tokenID);
        tierData[tier].amountStakedForPoints -= uint96(_amount);        

        UserDeposit memory deposit = _userDeposits[tokenID];
        _userDeposits[tokenID] = UserDeposit(
            deposit.amounts + uint128(_amount),
            deposit.amountStakedForPoints - uint128(_amount)
        );
    }

    function _incrementUserDeposit(uint256 tokenID, uint256 _amount, uint256 _amountStakedForPoints) internal {
        UserDeposit memory deposit = _userDeposits[tokenID];
        _userDeposits[tokenID] = UserDeposit(
            deposit.amounts + uint128(_amount),
            deposit.amountStakedForPoints + uint128(_amountStakedForPoints)
        );
    }

    function _decrementUserDeposit(uint256 tokenID, uint256 _amount, uint256 _amountStakedForPoints) internal {
        UserDeposit memory deposit = _userDeposits[tokenID];
        _userDeposits[tokenID] = UserDeposit(
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

    function _initializeEarlyAdopterPoolUserPoints(uint256 tokenID, uint40 _points, uint256 _amount) internal {
        UserData storage userData = _userData[tokenID];
        userData.pointsSnapshot = _points;
        userData.pointsSnapshotTime = uint32(block.timestamp);
        uint40 userPointsPerDepositAmount = calculatePointsPerDepositAmount(_points, _amount);
        userData.tier = tierForPointsPerDepositAmount(userPointsPerDepositAmount);
    }

    function _claimTier(uint256 tokenID) internal {
        uint8 oldTier = tierOf(tokenID);
        uint8 newTier = claimableTier(tokenID);
        _claimTier(tokenID, oldTier, newTier);
    }

    function _claimTier(uint256 tokenID, uint8 _curTier, uint8 _newTier) internal {
        require(tierOf(tokenID) == _curTier, "the account does not belong to the specified tier");
        if (_curTier == _newTier) {
            return;
        }

        uint256 amount = _min(_userDeposits[tokenID].amounts, tierDeposits[_curTier].amounts);
        uint256 share = liquidityPool.sharesForAmount(amount);
        uint256 amountStakedForPoints = _userDeposits[tokenID].amountStakedForPoints;

        tierData[_curTier].amountStakedForPoints -= uint96(amountStakedForPoints);
        _decrementTierDeposit(_curTier, amount, share);

        tierData[_newTier].amountStakedForPoints += uint96(amountStakedForPoints);
        _incrementTierDeposit(_newTier, amount, share);

        _userData[tokenID].rewardsLocalIndex = tierData[_newTier].rewardsGlobalIndex;
        _userData[tokenID].tier = _newTier;
    }

    // Compute the points earnings of a user between [since, until) 
    // Assuming the user's balance didn't change in between [since, until)
    function _pointsEarning(uint256 tokenID, uint256 _since, uint256 _until) internal view returns (uint40) {
        UserDeposit storage userDeposit = _userDeposits[tokenID];
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

    function _applyUnwrapPenaltyByDeductingPointsEarnings(uint256 tokenID, uint256 _prevAmount, uint256 _burnAmount) internal {
        UserData storage userData = _userData[tokenID];
        userData.curTierPoints -= uint40(userData.curTierPoints * _burnAmount / _prevAmount);
        userData.nextTierPoints -= uint40(userData.nextTierPoints * _burnAmount / _prevAmount);
        _claimTier(tokenID);
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

    /*
    function name() public pure returns (string memory) { return "meETH token"; }
    function symbol() public pure returns (string memory) { return "meETH"; }
    function decimals() public pure returns (uint8) { return 18; }
    */

    function totalShares() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < tierDeposits.length; i++) {
            sum += uint256(tierDeposits[i].shares);
        }
        return sum;
    }


    /*
    function totalSupply() public view override(IERC20Upgradeable, ImeETH) returns (uint256) {
        return liquidityPool.amountForShare(totalShares());
    }
    */


    function pointsOf(uint256 tokenID) public view returns (uint40) {
        UserData storage userData = _userData[tokenID];
        uint40 points = userData.pointsSnapshot;
        uint40 pointsEarning = _pointsEarning(tokenID, userData.pointsSnapshotTime, block.timestamp);

        uint40 total = 0;
        if (uint256(points) + uint256(pointsEarning) >= type(uint40).max) {
            total = type(uint40).max;
        } else {
            total = points + pointsEarning;
        }
        return total;
    }

    function pointsSnapshotTimeOf(uint256 tokenID) public view returns (uint32) {
        return _userData[tokenID].pointsSnapshotTime;
    }

    function tierOf(uint256 tokenID) public view returns (uint8) {
        return _userData[tokenID].tier;
    }

    // This function calculates the points earned by the account for the current tier.
    // It takes into account the account's points earned since the previous tier snapshot,
    // as well as any points earned during the current tier snapshot period.
    function getPointsEarningsDuringLastMembershipPeriod(uint256 tokenID) public view returns (uint40) {
        UserData storage userData = _userData[tokenID];
        uint256 userPointsSnapshotTimestamp = userData.pointsSnapshotTime;
        // Get the timestamp for the recent tier snapshot
        uint256 tierSnapshotTimestamp = recentTierSnapshotTimestamp();
        int256 timeBetweenSnapshots = int256(tierSnapshotTimestamp) - int256(userPointsSnapshotTimestamp);

        // Calculate the points earned by the account for the current tier
        if (timeBetweenSnapshots > 28 days) {
            return _pointsEarning(tokenID, tierSnapshotTimestamp - 28 days, tierSnapshotTimestamp);
        } else if (timeBetweenSnapshots > 0) {
            return userData.nextTierPoints + _pointsEarning(tokenID, userPointsSnapshotTimestamp, tierSnapshotTimestamp);
        } else {
            return userData.curTierPoints;
        }
    }

    function claimableTier(uint256 tokenID) public view returns (uint8) {
        UserDeposit memory deposit = _userDeposits[tokenID];
        uint256 userTotalDeposit = uint256(deposit.amounts + deposit.amountStakedForPoints);
        uint40 pointsEarned = getPointsEarningsDuringLastMembershipPeriod(tokenID);
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
        uint40 userPointsPerDepositAmount;
        if (userTotalDepositScaled > 0) {
            userPointsPerDepositAmount = uint40(_points / userTotalDepositScaled); // points earned per 0.001 ether
        }
        return userPointsPerDepositAmount;
    }

    function recentTierSnapshotTimestamp() public view returns (uint256) {
        uint256 monthInSeconds = 4 * 7 * 24 * 3600;
        uint256 i = (block.timestamp - genesisTime) / monthInSeconds;
        return genesisTime + i * monthInSeconds;
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

