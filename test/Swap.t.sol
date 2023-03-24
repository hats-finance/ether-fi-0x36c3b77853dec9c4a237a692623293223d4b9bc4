// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/Swap.sol";

address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

contract UniV3Test is Test {
    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);
    IERC20 private usdc = IERC20(USDC);

    Swap private uni = new Swap();

    address alice = vm.addr(2);


    function setUp() public {}

    function test_SingleHop() public {
        weth.deposit{value: 2 ether}();
        weth.approve(address(uni), 1e18);

        uint amountOut = uni.swapExactInputSingleHop(DAI, 1e18);

        console.log("DAI", amountOut);

    }
}