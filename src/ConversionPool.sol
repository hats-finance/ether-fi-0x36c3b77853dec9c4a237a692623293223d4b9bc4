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

contract ConversionPool is Ownable, ReentrancyGuard, Pausable {
    
    using SafeERC20 for IERC20;


    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint24 public constant poolFee = 3000;

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

    mapping(address => mapping(address => uint256)) public finalUserToErc20Balance;

    /// @notice Allows ether to be sent to this contract
    receive() external payable {
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(address _routerAddress, address _liquidityPool) {
        swapRouter = ISwapRouter(_routerAddress);
        liquidityPool = ILiquidityPool(_liquidityPool);
        rETHInstance = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
        wstETHInstance = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        sfrxETHInstance = IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F);
        cbETHInstance = IERC20(0xBe9895146f7AF43049ca1c1AE358B0541Ea49704);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    // function withdrawERC20() external {
    //     uint256 rETHbal = finalUserToErc20Balance[msg.sender][rETH];
    //     uint256 wstETHbal = finalUserToErc20Balance[msg.sender][wstETH];
    //     uint256 sfrxEthbal = finalUserToErc20Balance[msg.sender][sfrxETH];
    //     uint256 cbEthBal = finalUserToErc20Balance[msg.sender][cbETH];

    //     finalUserToErc20Balance[msg.sender][rETH] = 0;
    //     finalUserToErc20Balance[msg.sender][wstETH] = 0;
    //     finalUserToErc20Balance[msg.sender][sfrxETH] = 0;
    //     finalUserToErc20Balance[msg.sender][cbETH] = 0;

    //     rETHInstance.safeTransfer(msg.sender, rETHbal);
    //     wstETHInstance.safeTransfer(msg.sender, wstETHbal);
    //     sfrxETHInstance.safeTransfer(msg.sender, sfrxEthbal);
    //     cbETHInstance.safeTransfer(msg.sender, cbEthBal);
    // }

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

    function _sendTokensToLP() internal {
        //Call function in LP and send in user and amount of ether sent
        (bool sent, ) = address(liquidityPool).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------------   GETTERS  -------------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  MODIFIERS  ------------------------------------
    //--------------------------------------------------------------------------------------

}
