// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;

import "@uniswap/contracts/interfaces/ISwapRouter.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ConversionPool is Ownable, ReentrancyGuard, Pausable {
   

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    ISwapRouter public immutable swapRouter;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------


    /// @notice Allows ether to be sent to this contract
    receive() external payable {}

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(address _routerAddress) {
        swapRouter = ISwapRouter(_routerAddress);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    function swapExactInputSingle(uint256 amountIn)
        external
        returns (uint256 amountOut)
    {
        linkToken.approve(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: LINK,
                tokenOut: WETH,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter.exactInputSingle(params);
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

    //--------------------------------------------------------------------------------------
    //-------------------------------------     GETTERS  -----------------------------------
    //--------------------------------------------------------------------------------------

    //--------------------------------------------------------------------------------------
    //-------------------------------------  MODIFIERS  ------------------------------------
    //--------------------------------------------------------------------------------------

}
