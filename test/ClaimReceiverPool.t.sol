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

    EarlyAdopterPool public adopterPool;
    
    IWETH private weth = IWETH(WETH);
    IERC20 private dai = IERC20(DAI);

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
        vm.prank(owner);
        claimReceiverPoolInstance.updateMerkleRoot(rootMigration);
        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0 ether}(10, 0, 0, 0, 400, proof1);
        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof2);
        vm.expectRevert("Verification failed");
        claimReceiverPoolInstance.deposit{value: 0 ether}(0, 10, 0, 50, 400, proof3);
    }

    function test_MigrateWorksCorrectly() public {
        bytes32[] memory proof1 = merkleMigration.getProof(dataForVerification, 1);

        vm.prank(owner);
        claimReceiverPoolInstance.updateMerkleRoot(rootMigration);

        assertEq(scoreManagerInstance.scores(0, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), bytes32(abi.encodePacked(uint256(0))));
        assertEq(scoreManagerInstance.totalScores(0), bytes32(abi.encodePacked(uint256(0))));

        startHoax(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);

        assertEq(address(claimReceiverPoolInstance).balance, 0 ether);
        assertEq(address(liquidityPoolInstance).balance, 0.2 ether);
        assertEq(
            eETHInstance.balanceOf(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931),
            0.2 ether
        );
        assertEq(scoreManagerInstance.scores(0, 0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931), bytes32(abi.encodePacked(uint256(652))));


        vm.expectRevert("Already Deposited");
        claimReceiverPoolInstance.deposit{value: 0.2 ether}(0, 0, 0, 0, 652, proof1);
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
}
