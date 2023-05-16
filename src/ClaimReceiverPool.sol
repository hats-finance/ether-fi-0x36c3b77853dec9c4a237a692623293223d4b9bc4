// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/security/PausableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/ImeETH.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IRegulationsManager.sol";


contract ClaimReceiverPool is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint24 public poolFee;

    // Mainnet Addresses
    // address private immutable rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    // address private immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    // address private immutable sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    // address private immutable cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;

    //Testnet addresses
    address private wEth;
    address private rETH;
    address private wstETH;
    address private sfrxETH;
    address private cbETH;

    bytes32 public merkleRoot;

    //SwapRouter but Testnet, although address is actually the same
    ISwapRouter public router;

    //Goerli Weth address used for unwrapping ERC20 Weth
    IWETH public wethContract;

    ILiquidityPool public liquidityPool;
    IRegulationsManager public regulationsManager;
    ImeETH public meEth;

    uint256[4] public __gap;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event MerkleUpdated(bytes32, bytes32);
    event FundsMigrated(address user, uint256 amount, uint256 eapPoints, uint40 loyaltyPoints);

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize to set variables on deployment
    function initialize(
        address _rEth,
        address _wstEth,
        address _sfrxEth,
        address _cbEth,
        address _regulationsManager,
        address _wethContract,
        address _uniswapRouter
    ) external initializer {
        require(_rEth  != address(0), "No zero addresses");
        require(_wstEth != address(0), "No zero addresses");
        require(_sfrxEth != address(0), "No zero addresses");
        require(_cbEth != address(0), "No zero addresses");
        require(_regulationsManager != address(0), "No zero addresses");

        rETH = _rEth;
        wstETH = _wstEth;
        sfrxETH = _sfrxEth;
        cbETH = _cbEth;

        regulationsManager = IRegulationsManager(_regulationsManager);
        router = ISwapRouter(_uniswapRouter);
        wethContract = IWETH(_wethContract);
        wEth = _wethContract;
        poolFee = 3_000;
        
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice EarlyAdopterPool users can re-deposit and mint meETH claiming their points & tiers
    /// @dev The deposit amount must be the same as what they deposited into the EAP
    /// @param _rEthBal balance of the token to be sent in
    /// @param _wstEthBal balance of the token to be sent in
    /// @param _sfrxEthBal balance of the token to be sent in
    /// @param _cbEthBal balance of the token to be sent in
    /// @param _points points of the user
    /// @param _merkleProof array of hashes forming the merkle proof for the user
    /// @param _slippageLimit slippage limit in basis points
    function deposit(
        uint256 _rEthBal,
        uint256 _wstEthBal,
        uint256 _sfrxEthBal,
        uint256 _cbEthBal,
        uint256 _points,
        bytes32[] calldata _merkleProof,
        uint256 _slippageLimit
    ) external payable whenNotPaused {
        require(_points > 0, "You don't have any point to claim");
        require(regulationsManager.isEligible(regulationsManager.whitelistVersion(), msg.sender), "User is not whitelisted");
        _verifyEapUserData(msg.sender, msg.value, _rEthBal, _wstEthBal, _sfrxEthBal, _cbEthBal, _points, _merkleProof);

        uint256 _ethAmount = 0;
        _ethAmount += msg.value;
        _ethAmount += _swapERC20ForETH(rETH, _rEthBal, _slippageLimit);
        _ethAmount += _swapERC20ForETH(wstETH, _wstEthBal, _slippageLimit);
        _ethAmount += _swapERC20ForETH(sfrxETH, _sfrxEthBal, _slippageLimit);
        _ethAmount += _swapERC20ForETH(cbETH, _cbEthBal, _slippageLimit);

        uint40 loyaltyPoints = convertEapPointsToLoyaltyPoints(_points);
        meEth.wrapEthForEap{value: _ethAmount}(msg.sender, loyaltyPoints, _merkleProof);

        emit FundsMigrated(msg.sender, _ethAmount, _points, loyaltyPoints);
    }

    function convertEapPointsToLoyaltyPoints(uint256 _eapPoints) public view returns (uint40) {
        uint256 points = (_eapPoints * 1e14 / 1000) / 1 days / 0.001 ether;
        if (points >= type(uint40).max) {
            points = type(uint40).max;
        }
        return uint40(points);
    }

    function setLiquidityPool(address _address) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        liquidityPool = ILiquidityPool(_address);
    }

    function setMeEth(address _address) external onlyOwner {
        require(_address != address(0), "Cannot be address zero");
        meEth = ImeETH(_address);
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unPauseContract() external onlyOwner {
        _unpause();
    }

    /// @notice Updates the merkle root
    /// @param _newMerkle new merkle root used to verify the EAP user data (deposits, points)
    function updateMerkleRoot(bytes32 _newMerkle) external onlyOwner {
        bytes32 oldMerkle = merkleRoot;
        merkleRoot = _newMerkle;
        emit MerkleUpdated(oldMerkle, _newMerkle);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------  INTERNAL FUNCTIONS  --------------------------------
    //--------------------------------------------------------------------------------------

    function _verifyEapUserData(
        address _user,
        uint256 _ethBal,
        uint256 _rEthBal,
        uint256 _wstEthBal,
        uint256 _sfrxEthBal,
        uint256 _cbEthBal,
        uint256 _points,
        bytes32[] calldata _merkleProof
    ) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _ethBal, _rEthBal, _wstEthBal, _sfrxEthBal, _cbEthBal, _points));
        bool verified = MerkleProof.verify(_merkleProof, merkleRoot, leaf);
        require(verified, "Verification failed");
    }

    function _swapERC20ForETH(address _token, uint256 _amount, uint256 _slippageBasisPoints) internal returns (uint256) {
        if (_amount == 0) {
            return 0;
        }
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 amountOut = _swapExactInputSingle(_amount, _token, _slippageBasisPoints);
        wethContract.withdraw(amountOut);
        return amountOut;
    }

    function _swapExactInputSingle(
        uint256 _amountIn,
        address _tokenIn,
        uint256 _slippageLimit
    ) internal returns (uint256 amountOut) {
        IERC20(_tokenIn).approve(address(router), _amountIn);
        uint256 minimumAmountAfterSlippage = _amountIn - (_amountIn * _slippageLimit) / 10_000;
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: wEth,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp + 100,
                amountIn: _amountIn,
                amountOutMinimum: minimumAmountAfterSlippage,
                sqrtPriceLimitX96: 0
            });
        amountOut = router.exactInputSingle(params);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
