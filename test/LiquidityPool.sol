// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";

contract BNFTTest is Test {
    LiquidityPool public liquidityPool;
    EETH public eETH;
   
    address owner = vm.addr(1);
    address alice = vm.addr(2);

    function setUp() public {
        vm.startPrank(owner);
        liquidityPool = new LiquidityPool(owner);
        eETH = new EETH(address(liquidityPool));
        liquidityPool.setTokenAddress(address(eETH));
        vm.stopPrank();
    }

    function test_DepositLiquidityPool() public {
        assertEq(true,true);
    }
}