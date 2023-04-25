pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EarlyAdopterPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/murky/src/Merkle.sol";
import "./TestERC20.sol";
import "./TestSetup.sol";
import "../src/interfaces/IScoreManager.sol";

contract ClaimReceiverPoolTest is TestSetup {
    //goerli addresses
    address constant WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant DAI = 0xdc31Ee1784292379Fbb2964b3B9C4124D8F89C60;

    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);

    EarlyAdopterPool public adopterPool;

    function setUp() public {
        
        setUpTests();

        vm.startPrank(owner);
        adopterPool = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth)
        );
        vm.stopPrank();
    }

    function test_DepositFailsWithIncorrectMerkle() public {
        bytes32[] memory proof1 = merkle.getProof(dataForVerification, 0);
        bytes32[] memory proof2 = merkle.getProof(dataForVerification, 1);
        bytes32[] memory proof3 = merkle.getProof(dataForVerification, 2);
        
        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        regulationsManagerInstance.confirmEligibility("Hash_Example");

        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0 ether}(10, 0, 0, 0, 400, proof1);
        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0.3 ether}(0, 0, 0, 0, 652, proof2);
        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0 ether}(0, 10, 0, 50, 400, proof3);
    }

    function test_MigrateWorksCorrectly() public {
        bytes32[] memory proof1 = merkleMigration.getProof(dataForVerification, 1);

        vm.prank(owner);

        assertEq(scoreManagerInstance.scores(0, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 0);
        assertEq(scoreManagerInstance.totalScores(0), 0);

        assertEq(scoreManagerInstance.scores(0, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),0);
        assertEq(scoreManagerInstance.totalScores(0), 0);

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        vm.expectRevert("User is not whitelisted");
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);

        regulationsManagerInstance.confirmEligibility("Hash_Example");
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);

        assertEq(address(claimReceiverPoolInstance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0.2 ether);
        assertEq(
            eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            0.2 ether
        );
        assertEq(scoreManagerInstance.scores(0, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), 652);


        vm.expectRevert("Already Deposited");
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);
        vm.stopPrank();

        vm.deal(owner, 100 ether);
        vm.prank(owner);
        liquidityPoolInstance.accrueEapRewards{value: 1 ether}();
        assertEq(
            eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            0.2 ether + 1 ether
        );

        vm.prank(owner);
        liquidityPoolInstance.accrueEapRewards{value: 10 ether}();
        assertEq(
            eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            0.2 ether + 1 ether + 10 ether
        );
    }

    function test_SetLPAddressFailsIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Cannot be address zero");
        claimReceiverPoolInstance.setLiquidityPool(address(0));
    }

    function test_SetLPAddressFailsIfNonOwner() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        claimReceiverPoolInstance.setLiquidityPool(address(liquidityPoolInstance));
    }


    function test_EapRewardsWorksCorrectly() public {
        bytes32[] memory bobProof = merkle.getProof(dataForVerification, 3);
        bytes32[] memory danProof = merkle.getProof(dataForVerification, 4);

        vm.deal(bob, 0.1 ether);
        vm.deal(dan, 0.1 ether);

        vm.startPrank(bob);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        claimReceiverPoolInstance.deposit{value: 0.1 ether}(0, 0, 0, 0, 400, bobProof);
        assertEq(scoreManagerInstance.scores(0, bob), 400);
        assertEq(scoreManagerInstance.totalScores(0), 400);
        vm.stopPrank();

        vm.startPrank(dan);
        regulationsManagerInstance.confirmEligibility("Hash_Example");
        claimReceiverPoolInstance.deposit{value: 0.1 ether}(0, 0, 0, 0, 800, danProof);
        assertEq(scoreManagerInstance.scores(0, dan), 800);
        assertEq(scoreManagerInstance.totalScores(0), 1200);
        vm.stopPrank();

        assertEq(eETHInstance.balanceOf(bob), 0.1 ether);
        assertEq(eETHInstance.balanceOf(dan), 0.1 ether);

        vm.deal(owner, 100 ether);
        vm.prank(owner);
        liquidityPoolInstance.accrueEapRewards{value: 3 ether}();

        assertEq(eETHInstance.balanceOf(bob), 0.1 ether + 1 ether);
        assertEq(eETHInstance.balanceOf(dan), 0.1 ether + 2 ether);
    }
}
