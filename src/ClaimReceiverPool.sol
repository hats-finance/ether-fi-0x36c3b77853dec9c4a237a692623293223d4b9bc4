// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IWeth.sol";
import "./EarlyAdopterPool.sol";
import "lib/forge-std/src/console.sol";

contract ConversionPool is Ownable, ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;


    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint24 public constant poolFee = 500;

    // address private immutable rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    // address private immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    // address private immutable sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    // address private immutable cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address private immutable wEth;

    address private immutable rETH;
    address private immutable wstETH;
    address private immutable sfrxETH;
    address private immutable cbETH;

    ISwapRouter public immutable swapRouter;
    ILiquidityPool public liquidityPool;
    IWETH public wethContract;
    IERC20 public rETHInstance;
    IERC20 public wstETHInstance;
    IERC20 public sfrxETHInstance;
    IERC20 public cbETHInstance;

    EarlyAdopterPool public adopterPool;

    mapping(address => mapping(address => uint256)) public userToERC20Deposit;
    mapping(address => uint256) public etherBalance;
    mapping(address => uint256) public userPoints;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------


    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(
        address _routerAddress, 
        address _liquidityPool, 
        address _adopterPool, 
        address _rEth, 
        address _wstEth, 
        address _sfrxEth, 
        address _cbEth,
        address _wEth
    ) {
        swapRouter = ISwapRouter(_routerAddress);
        liquidityPool = ILiquidityPool(_liquidityPool);
        wethContract = IWETH(_wEth);

        //rETHInstance = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
        //wstETHInstance = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        //sfrxETHInstance = IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F);
        //cbETHInstance = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);

        rETHInstance = IERC20(_rEth);
        wstETHInstance = IERC20(_wstEth);
        sfrxETHInstance = IERC20(_sfrxEth);
        cbETHInstance = IERC20(_cbEth);

        rETH = _rEth;
        wstETH = _wstEth;
        sfrxETH = _sfrxEth;
        cbETH = _cbEth;
        wEth = _wEth;

        adopterPool = EarlyAdopterPool(payable(_adopterPool));
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function setPointsData(address _user, uint256 _points) external {
        userPoints[_user] = _points;
    }

    function depositEther() external payable {
        (, uint256 earlyAdopterPoolBalance, ) = adopterPool.depositInfo(msg.sender);
        require(earlyAdopterPoolBalance == msg.value, "Incorrect amount");

        etherBalance[msg.sender] += msg.value;
    }

    function depositERC20(address _erc20Contract, uint256 _amount) external {

        uint256 earlyAdopterPoolBalance = adopterPool.userToErc20Balance(msg.sender, _erc20Contract);
        require(earlyAdopterPoolBalance == _amount, "Incorrect amount");
        
        require(
            (_erc20Contract == rETH ||
                _erc20Contract == sfrxETH ||
                _erc20Contract == wstETH ||
                _erc20Contract == cbETH),
            "Unsupported token"
        );

        userToERC20Deposit[msg.sender][_erc20Contract] = _amount;
        require(IERC20(_erc20Contract).safeTransferFrom(msg.sender, address(this), _amount), "Transfer failed");
    }

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------  INTERNAL FUNCTIONS  --------------------------------
    //--------------------------------------------------------------------------------------

    function _swapForTotalWETH(
        uint256 _rEthSentIn, 
        uint256 _wstEthSentIn, 
        uint256 _sfrxEthSentIn, 
        uint256 _cbEthSentIn
    ) internal returns (uint256){
        uint256 wethBalance;
        if(_rEthSentIn > 0){
            console.log("Beginning of swap for rEth");
            wethBalance += _swapExactInputSingle(_rEthSentIn, rETH);
        }

        if(_wstEthSentIn > 0){
            wethBalance += _swapExactInputSingle(_wstEthSentIn, wstETH);
        }

        if(_sfrxEthSentIn > 0){
            wethBalance += _swapExactInputSingle(_sfrxEthSentIn, sfrxETH);
        }

        if(_cbEthSentIn > 0){
            wethBalance += _swapExactInputSingle(_cbEthSentIn, cbETH);
        }

        return wethBalance;
    }

    function _swapExactInputSingle(uint256 _amountIn, address _tokenIn)
        internal
        returns (uint256 amountOut)
    {
        IERC20(_tokenIn).approve(address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: wEth,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------   GETTERS  -------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  MODIFIERS  ------------------------------------
    //--------------------------------------------------------------------------------------

}