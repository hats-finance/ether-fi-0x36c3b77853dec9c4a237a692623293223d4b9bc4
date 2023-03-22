// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ConversionPool.sol";
import "../src/LiquidityPool.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/EETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TestERC20.sol";

contract ConversionPoolTest is Test {

    ConversionPool public conversionPoolInstance;
    EarlyAdopterPool public earlyAdopterPoolInstance;
    LiquidityPool public liqPool;

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;
    IERC20 public testDai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    EETH public eEth;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    
    function setUp() public {
        vm.startPrank(owner);

        rETH = new TestERC20("Rocket Pool ETH", "rETH");
        rETH.mint(alice, 10e18);

        cbEth = new TestERC20("Staked ETH", "wstETH");
        cbEth.mint(alice, 10e18);

        wstETH = new TestERC20("Coinbase ETH", "cbEth");
        wstETH.mint(alice, 10e18);

        sfrxEth = new TestERC20("Frax ETH", "sfrxEth");
        sfrxEth.mint(alice, 10e18);

        liqPool = new LiquidityPool(owner);

        eEth = new EETH(address(liqPool));
        
        earlyAdopterPoolInstance = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth)
        );

        conversionPoolInstance = new ConversionPool(
            0xE592427A0AEce92De3Edee1F18E0157C05861564, 
            address(liqPool), 
            address(earlyAdopterPoolInstance),
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth),
            address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        );

        vm.stopPrank();
    }

    function test_ConversionPoolReceivesERC20() public {
        vm.startPrank(alice);
        rETH.approve(address(earlyAdopterPoolInstance), 10 ether);
        earlyAdopterPoolInstance.deposit(address(rETH), 10e18);
        vm.stopPrank();

        vm.startPrank(owner);
        earlyAdopterPoolInstance.setClaimingOpen(2 days);
        earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
        liqPool.setTokenAddress(address(eEth));
        vm.stopPrank();

        vm.startPrank(alice);
        earlyAdopterPoolInstance.claim();

        assertEq(rETH.balanceOf(address(conversionPoolInstance)), 10 ether);
    }

    // function test_SendEtherToLPFailsIfAlreadyClaimed() public {
    //     hoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
    //     earlyAdopterPoolInstance.depositEther{value: 2 ether}();
        
    //     vm.startPrank(owner);
    //     earlyAdopterPoolInstance.setClaimingOpen(2 days);
    //     earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
    //     liqPool.setTokenAddress(address(eEth));
    //     vm.stopPrank();
        
    //     startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
    //     earlyAdopterPoolInstance.claim();

    //     conversionPoolInstance.sendFundsToLP();
        
    //     vm.expectRevert("Already sent funds for user");
    //     conversionPoolInstance.sendFundsToLP();
    // }

    // function test_SendEtherToLPFailsIfNothingToSend() public {    
    //     vm.startPrank(owner);
    //     earlyAdopterPoolInstance.setClaimingOpen(2 days);
    //     earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
    //     liqPool.setTokenAddress(address(eEth));
    //     vm.stopPrank();
        
    //     startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        
    //     vm.expectRevert("No funds available to transfer");
    //     conversionPoolInstance.sendFundsToLP();
    // }

    // function test_SendEtherToLPWorksCorrectly() public {
    //     hoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
    //     earlyAdopterPoolInstance.depositEther{value: 2 ether}();
        
    //     vm.startPrank(owner);
    //     earlyAdopterPoolInstance.setClaimingOpen(2 days);
    //     earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
    //     liqPool.setTokenAddress(address(eEth));
    //     vm.stopPrank();
        
    //     startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
    //     earlyAdopterPoolInstance.claim();

    //     assertEq(address(conversionPoolInstance).balance, 2 ether);
    
    //     conversionPoolInstance.sendFundsToLP();
    //     assertEq(address(conversionPoolInstance).balance, 0 ether);
    //     assertEq(address(liqPool).balance, 2 ether);
    // }

    function test_ReceiveFunctionWorksCorrectly() public {
        vm.startPrank(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        rETH.mint(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, 10e18);
        rETH.approve(address(earlyAdopterPoolInstance), 10 ether);
        earlyAdopterPoolInstance.deposit(address(rETH), 10e18);

        cbEth.mint(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, 10e18);
        cbEth.approve(address(earlyAdopterPoolInstance), 10 ether);
        earlyAdopterPoolInstance.deposit(address(cbEth), 1e18);
        vm.stopPrank();

        vm.startPrank(owner);
        earlyAdopterPoolInstance.setClaimingOpen(2 days);
        earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
        liqPool.setTokenAddress(address(eEth));
        vm.stopPrank();

        vm.startPrank(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        earlyAdopterPoolInstance.claim();

        assertEq(conversionPoolInstance.finalUserToErc20Balance(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, address(rETH)), 10e18);
        assertEq(conversionPoolInstance.finalUserToErc20Balance(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, address(cbEth)), 1e18);
        assertEq(conversionPoolInstance.finalUserToErc20Balance(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, address(wstETH)), 0);
        assertEq(conversionPoolInstance.finalUserToErc20Balance(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA, address(sfrxEth)), 0);
    }

    function test_Swap() public {
        startHoax(0x7C5aaA2a20b01df027aD032f7A768aC015E77b86);
        testDai.transfer(address(conversionPoolInstance), 1);

        conversionPoolInstance._swapExactInputSingle(100, 0x6B175474E89094C44Da98b954EedeAC495271d0F);
    }
}
