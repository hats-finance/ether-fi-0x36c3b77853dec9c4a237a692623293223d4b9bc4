// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/ConversionPool.sol";
import "../src/LiquidityPool.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/EETH.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./TestERC20.sol";

contract ConversionPoolTest is Test {

    ConversionPool public conversionPoolInstance;
    EarlyAdopterPool public earlyAdopterPoolInstance;
    LiquidityPool public liqPool;

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;

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

        conversionPoolInstance = new ConversionPool(0xE592427A0AEce92De3Edee1F18E0157C05861564, address(liqPool), address(earlyAdopterPoolInstance));
        
        vm.stopPrank();
    }

    function test_ConversionPoolReceivesEther() public {
        hoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        (bool sent, ) = address(conversionPoolInstance).call{value: 2 ether}("");

        assertEq(address(conversionPoolInstance).balance, 2 ether);
    }

    function test_SendEtherToLPFailsIfAlreadyClaimed() public {
        hoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        earlyAdopterPoolInstance.depositEther{value: 2 ether}();
        
        vm.startPrank(owner);
        earlyAdopterPoolInstance.setClaimingOpen(2 days);
        earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
        liqPool.setTokenAddress(address(eEth));
        vm.stopPrank();
        
        startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        conversionPoolInstance.setData();
        earlyAdopterPoolInstance.claim();

        conversionPoolInstance.sendFundsToLP();
        
        vm.expectRevert("Already sent funds for user");
        conversionPoolInstance.sendFundsToLP();
    }

    function test_SendEtherToLPFailsIfNothingToSend() public {    
        vm.startPrank(owner);
        earlyAdopterPoolInstance.setClaimingOpen(2 days);
        earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
        liqPool.setTokenAddress(address(eEth));
        vm.stopPrank();
        
        startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        conversionPoolInstance.setData();
        
        vm.expectRevert("No funds available to transfer");
        conversionPoolInstance.sendFundsToLP();
    }

    function test_SendEtherToLPWorksCorrectly() public {
        hoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        earlyAdopterPoolInstance.depositEther{value: 2 ether}();
        
        vm.startPrank(owner);
        earlyAdopterPoolInstance.setClaimingOpen(2 days);
        earlyAdopterPoolInstance.setClaimReceiverContract(address(conversionPoolInstance));
        liqPool.setTokenAddress(address(eEth));
        vm.stopPrank();
        
        startHoax(0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA);
        conversionPoolInstance.setData();
        earlyAdopterPoolInstance.claim();

        assertEq(address(conversionPoolInstance).balance, 2 ether);
        conversionPoolInstance.sendFundsToLP();
        assertEq(address(conversionPoolInstance).balance, 0 ether);
        assertEq(address(liqPool).balance, 2 ether);
    }
}
