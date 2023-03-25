// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/ClaimReceiverPool.sol";
import "../src/EarlyAdopterPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./TestERC20.sol";

contract ClaimReceiverPoolTest is Test {

    //goerli addresses
    address constant WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant DAI = 0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60;

    ClaimReceiverPool public claimReceiverPool;
    EarlyAdopterPool public adopterPool;

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;

    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);


    function setUp() public {
        rETH = new TestERC20("Rocket Pool ETH", "rETH");
        rETH.mint(alice, 10e18);
        rETH.mint(bob, 10e18);

        cbEth = new TestERC20("Staked ETH", "wstETH");
        cbEth.mint(alice, 10e18);
        cbEth.mint(bob, 10e18);

        wstETH = new TestERC20("Coinbase ETH", "cbEth");
        wstETH.mint(alice, 10e18);
        wstETH.mint(bob, 10e18);

        sfrxEth = new TestERC20("Frax ETH", "sfrxEth");
        sfrxEth.mint(alice, 10e18);
        sfrxEth.mint(bob, 10e18);

        vm.startPrank(owner);
        adopterPool = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth)
        );

        claimReceiverPool = new ClaimReceiverPool(
            address(adopterPool),
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth)
        );

        vm.stopPrank();
    }

    function test_DepositUsingOneFunction() public {
        startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        adopterPool.depositEther{value: 2 ether}();

        rETH.mint(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, 10e18);
        rETH.approve(address(adopterPool), 10e18);
        adopterPool.deposit(address(rETH), 1e18);

        assertEq(rETH.balanceOf(address(adopterPool)), 1e18);
        assertEq(address(adopterPool).balance, 2 ether);

        claimReceiverPool.fetchData();
        adopterPool.withdraw();

        rETH.approve(address(claimReceiverPool), 10e18);
        claimReceiverPool.deposit{value: 2 ether}(1e18, 0, 0, 0);

        assertEq(rETH.balanceOf(address(adopterPool)), 0);
        assertEq(address(adopterPool).balance, 0);

        assertEq(rETH.balanceOf(address(claimReceiverPool)), 1e18);
        assertEq(address(claimReceiverPool).balance, 2 ether);
    }

    // function test_SwapWorksCorrectly() public {
    //     startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
    //     dai.approve(address(claimReceiverPool), 349527451588596786087147);
    //     console.log(dai.balanceOf(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA));
    //     uint amountOut = claimReceiverPool._swapExactInputSingle(349527451588596786087147, DAI);

    //     console.log("WETH", amountOut);
    // }
} 
