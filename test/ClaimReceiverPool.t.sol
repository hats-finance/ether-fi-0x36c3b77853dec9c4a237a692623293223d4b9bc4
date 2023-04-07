// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/ClaimReceiverPool.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/murky/src/Merkle.sol";
import "../src/UUPSProxy.sol";

import "./TestERC20.sol";

contract ClaimReceiverPoolTest is Test {

    //goerli addresses
    address constant WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant DAI = 0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60;

    ClaimReceiverPool public claimReceiverPool;
    EarlyAdopterPool public adopterPool;
    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPoolInstance;
    EETH public eETHImplementation;
    EETH public eETHInstance;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public eETHProxy;

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;

    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);

    bytes32[] public whiteListedAddresses;
    Merkle merkle;
    bytes32 root;

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

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation), "");
        liquidityPoolInstance = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPoolInstance.initialize();

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation), "");
        eETHInstance = EETH(address(eETHProxy));
        eETHInstance.initialize(payable(address(liquidityPoolInstance)));

        claimReceiverPool.setLiquidityPool(address(liquidityPoolInstance));
        liquidityPoolInstance.setTokenAddress(address(eETHInstance));
        
        _merkleSetup();

        vm.stopPrank();
    }

    function test_DepositFailsWithIncorrectMerkle() public {
        bytes32[] memory proof1 = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof2 = merkle.getProof(whiteListedAddresses, 0);
        bytes32[] memory proof3 = merkle.getProof(whiteListedAddresses, 0);

        vm.prank(owner);
        claimReceiverPool.updateMerkleRoot(root);

        vm.expectRevert("Verification failed");
        claimReceiverPool.deposit{value: 0 ether}(1, 0, 0, 0, 400, proof1);

        vm.expectRevert("Verification failed");
        claimReceiverPool.deposit{value: 0.2 ether}(0, 0, 0, 10, 652, proof2);

        vm.expectRevert("Verification failed");
        claimReceiverPool.deposit{value: 0 ether}(0, 10, 0, 50, 400, proof3);
    }

    function test_MigrateFailsIfUserHasNoBalance() public {
        vm.prank(alice);
        vm.expectRevert("User has no funds");
        claimReceiverPool.migrateFunds();
    }

    function test_MigrateWorksCorrectly() public {
        bytes32[] memory proof1 = merkle.getProof(whiteListedAddresses, 1);
        
        vm.prank(owner);
        claimReceiverPool.updateMerkleRoot(root);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        claimReceiverPool.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);

        assertEq(address(claimReceiverPool).balance, 0.2 ether);
        assertEq(address(liquidityPoolInstance).balance, 0 ether);
        assertEq(eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);

        claimReceiverPool.migrateFunds();

        assertEq(address(claimReceiverPool).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0.2 ether);
        assertEq(eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0.2 ether);
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(uint256(0), uint256(10), uint256(0), uint256(0), uint256(0), uint256(400))
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(uint256(0.2 ether), uint256(0), uint256(0), uint256(0), uint256(0), uint256(652))
            )
        );
        whiteListedAddresses.push(
            keccak256(
                abi.encodePacked(uint256(0), uint256(10), uint256(0), uint256(50), uint256(0), uint256(9464))
            )
        );

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(bob)));

        root = merkle.getRoot(whiteListedAddresses);
    }
} 
