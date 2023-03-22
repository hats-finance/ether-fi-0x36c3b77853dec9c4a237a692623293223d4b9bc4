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
import "./EarlyAdopterPool.sol";
import "lib/forge-std/src/console.sol";

contract ConversionPool is Ownable, ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;


    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint24 public constant poolFee = 3000;

    //Being initialised to save first user higher gas fee
    uint256 public rEthBalance = 1;
    uint256 public wstEthBalance = 1;
    uint256 public sfrxEthBalance = 1;
    uint256 public cbEthBalance = 1;

    address private immutable rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private immutable sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address private immutable cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address private immutable wEth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    ISwapRouter public immutable swapRouter;
    ILiquidityPool public liquidityPool;
    IERC20 public rETHInstance;
    IERC20 public wstETHInstance;
    IERC20 public sfrxETHInstance;
    IERC20 public cbETHInstance;

    EarlyAdopterPool public adopterPool;

    mapping(address => mapping(address => uint256)) public finalUserToErc20Balance;
    mapping(address => bool) public claimed;
    mapping(address => uint256) public etherBalance;

    /// @notice Allows ether to be sent to this contract
    receive() external payable {
        etherBalance[tx.origin] = msg.value;

        uint256 rEthSentIn = rETHInstance.balanceOf(address(this)) - rEthBalance;
        uint256 wstEthSentIn = wstETHInstance.balanceOf(address(this)) - wstEthBalance;
        uint256 sfrxEthSentIn = sfrxETHInstance.balanceOf(address(this)) - sfrxEthBalance;
        uint256 cbEthSentIn = cbETHInstance.balanceOf(address(this)) - cbEthBalance;

        finalUserToErc20Balance[tx.origin][rETH] = rEthSentIn;
        finalUserToErc20Balance[tx.origin][wstETH] = wstEthSentIn;
        finalUserToErc20Balance[tx.origin][sfrxETH] = sfrxEthSentIn;
        finalUserToErc20Balance[tx.origin][cbETH] = cbEthSentIn;

        rEthBalance += rEthSentIn;
        wstEthBalance += wstEthSentIn;
        sfrxEthBalance += sfrxEthSentIn;
        cbEthBalance += cbEthSentIn;
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

    constructor(address _routerAddress, address _liquidityPool, address _adopterPool) {
        swapRouter = ISwapRouter(_routerAddress);
        liquidityPool = ILiquidityPool(_liquidityPool);
        rETHInstance = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
        wstETHInstance = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        sfrxETHInstance = IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F);
        cbETHInstance = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
        adopterPool = EarlyAdopterPool(payable(_adopterPool));
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Send funds of a user calling to the LP
    /// @dev How do we know they actually have claimed?
    function sendFundsToLP() external {
        require(claimed[msg.sender] == false, "Already sent funds for user");
        
        uint256 rEthBal = finalUserToErc20Balance[msg.sender][rETH];
        uint256 wstEthBal = finalUserToErc20Balance[msg.sender][wstETH];
        uint256 sfrxEthBal = finalUserToErc20Balance[msg.sender][sfrxETH];
        uint256 cbEthBal = finalUserToErc20Balance[msg.sender][cbETH];

        if(rEthBal > 0){
            etherBalance[msg.sender] += _swapExactInputSingle(rEthBal, rETH);
        }

        if(wstEthBal > 0){
            etherBalance[msg.sender] += _swapExactInputSingle(wstEthBal, wstETH);
        }

        if(sfrxEthBal > 0){
            etherBalance[msg.sender] += _swapExactInputSingle(sfrxEthBal, sfrxETH);
        }

        if(cbEthBal > 0){
            etherBalance[msg.sender] += _swapExactInputSingle(cbEthBal, cbETH);
        }

        require(etherBalance[msg.sender] > 0, "No funds available to transfer");
        claimed[msg.sender] = true;
        
        //Call function in LP and send in user and amount of ether sent
        liquidityPool.deposit{value: etherBalance[msg.sender]}(msg.sender);

        emit fundsSentToLP(msg.sender, etherBalance[msg.sender]);
    }

    /// @notice Sets the data from the Early Adopter Pool in the Conversion Pool
    /// @dev Must be called before claim in the Early Adopter Pool
    function setData(uint256 _etherBalance, uint256 rEthBal, uint256 wstEthBal, uint256 sfrxBal, uint256 cbEthBal, uint256 totalPoints) external {
       
        etherBalance[msg.sender] = _etherBalance;
        finalUserToErc20Balance[msg.sender][rETH] = rEthBal;
        finalUserToErc20Balance[msg.sender][wstETH] = wstEthBal;
        finalUserToErc20Balance[msg.sender][sfrxETH] = sfrxBal;
        finalUserToErc20Balance[msg.sender][cbETH] = cbEthBal;
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
