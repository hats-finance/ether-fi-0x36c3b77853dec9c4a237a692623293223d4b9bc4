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

    uint24 public constant poolFee = 3000;

    //Being initialised to save first user higher gas fee
    uint256 public rEthGlobalBalance;
    uint256 public wstEthGlobalBalance;
    uint256 public sfrxEthGlobalBalance;
    uint256 public cbEthGlobalBalance;

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

    mapping(address => mapping(address => uint256)) public finalUserToErc20Balance;
    mapping(address => uint256) public etherBalance;

    /// @notice Allows ether to be sent to this contract
    receive() external payable {
       
        etherBalance[tx.origin] = msg.value;

        uint256 rEthSentIn = rETHInstance.balanceOf(address(this)) - rEthGlobalBalance;
        uint256 wstEthSentIn = wstETHInstance.balanceOf(address(this)) - wstEthGlobalBalance;
        uint256 sfrxEthSentIn = sfrxETHInstance.balanceOf(address(this)) - sfrxEthGlobalBalance;
        uint256 cbEthSentIn = cbETHInstance.balanceOf(address(this)) - cbEthGlobalBalance;

        _updateBalances(rEthSentIn, wstEthSentIn, sfrxEthSentIn, cbEthSentIn, tx.origin);
        _updateGlobalVariables(rEthSentIn, wstEthSentIn, sfrxEthSentIn, cbEthSentIn);
        uint256 wethBal = _swapForTotalWETH(rEthSentIn, wstEthSentIn, sfrxEthSentIn, cbEthSentIn);

        wethContract.withdraw(wethBal);
        etherBalance[tx.origin] += wethBal;
       
        //Call function in LP and send in user and amount of ether sent
        liquidityPool.deposit{value: etherBalance[tx.origin]}(tx.origin);
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event fundsSentToLP(address user, uint256 amount);
    event DataSet(
        address user, 
        uint256 etherAmount, 
        uint256 rEthAMount,
        uint256 wstEthAmount,
        uint256 sfrxEthAmount,
        uint256 cbEthAmount
    );

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

    /// @notice Send funds of a user calling to the LP
    /// @dev How do we know they actually have claimed?
    function sendFundsToLP() external {
        //require(claimed[msg.sender] == false, "Already sent funds for user");
        
        // uint256 rEthBal = finalUserToErc20Balance[msg.sender][rETH];
        // uint256 wstEthBal = finalUserToErc20Balance[msg.sender][wstETH];
        // uint256 sfrxEthBal = finalUserToErc20Balance[msg.sender][sfrxETH];
        // uint256 cbEthBal = finalUserToErc20Balance[msg.sender][cbETH];

        // if(rEthBal > 0){
        //     etherBalance[msg.sender] += _swapExactInputSingle(rEthBal, rETH);
        // }

        // if(wstEthBal > 0){
        //     etherBalance[msg.sender] += _swapExactInputSingle(wstEthBal, wstETH);
        // }

        // if(sfrxEthBal > 0){
        //     etherBalance[msg.sender] += _swapExactInputSingle(sfrxEthBal, sfrxETH);
        // }

        // if(cbEthBal > 0){
        //     etherBalance[msg.sender] += _swapExactInputSingle(cbEthBal, cbETH);
        // }

        // require(etherBalance[msg.sender] > 0, "No funds available to transfer");
        // claimed[msg.sender] = true;
        
        // Call function in LP and send in user and amount of ether sent
        // liquidityPool.deposit{value: etherBalance[msg.sender]}(msg.sender);

        // emit fundsSentToLP(msg.sender, etherBalance[msg.sender]);
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

    function _updateGlobalVariables(
        uint256 _rEthSentIn, 
        uint256 _wstEthSentIn, 
        uint256 _sfrxEthSentIn, 
        uint256 _cbEthSentIn
    ) internal {
        rEthGlobalBalance += _rEthSentIn;
        wstEthGlobalBalance += _wstEthSentIn;
        sfrxEthGlobalBalance += _sfrxEthSentIn;
        cbEthGlobalBalance += _cbEthSentIn;
    }

    function _updateBalances( 
        uint256 _rEthSentIn, 
        uint256 _wstEthSentIn, 
        uint256 _sfrxEthSentIn, 
        uint256 _cbEthSentIn,
        address _user
    ) internal {
        finalUserToErc20Balance[_user][rETH] = _rEthSentIn;
        finalUserToErc20Balance[_user][wstETH] = _wstEthSentIn;
        finalUserToErc20Balance[_user][sfrxETH] = _sfrxEthSentIn;
        finalUserToErc20Balance[_user][cbETH] = _cbEthSentIn;
    }

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
        public
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
