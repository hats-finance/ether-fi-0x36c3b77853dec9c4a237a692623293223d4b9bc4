// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MainnetTestSetup.sol";
import "../../src/helpers/AddressProvider.sol";

contract FullWithdrawTest is MainnetTestSetup {

    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public zeroProof;

    uint256 mainnetFork;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        setUpTests();
    }

    function test_FullWithdrawError() public {
        //Moving to a specific block
        vm.rollFork(17987301);
        uint256 treasuryBalanceBefore = address(treasuryInstance).balance;
        console.log("Treasury balance before full withdrawal: ", treasuryBalanceBefore);
        console.log("NFT holders balance before full withdrawal: ", 0x4B8DF85d5BE4DF1e4D89840E5c7bd3F9D6361D48.balance);
        console.log("Operators balance before full withdrawal: ", 0xB6C9125584A1A28cCafd31056D4aF29014862536.balance);
        console.log("-----------------------------------------------------------------------------------------------------");

        (uint256 toOperator, uint256 toTNFT, uint256 toBNFT, uint256 toTreasury) = etherfiNodesManagerInstance.getFullWithdrawalPayouts(2);
        console.log("Amount operator is owed: ", toOperator);
        console.log("Amount TNFT holder is owed: ", toTNFT);
        console.log("Amount BNFT holder is owed: ", toBNFT);
        console.log("Amount treasury is owed: ", toTreasury);
        console.log("-----------------------------------------------------------------------------------------------------");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        AddressProvider addressProvider = AddressProvider(addressProviderAddress);

        address stakingManagerProxyAddress = addressProvider.getContractAddress("StakingManager");

        StakingManager stakingManager = StakingManager(stakingManagerProxyAddress);

        startHoax(0xF155a2632Ef263a6A382028B3B33feb29175b8A5);
        EtherFiNode etherFiNode = new EtherFiNode();
        stakingManager.upgradeEtherFiNode(address(etherFiNode));

        vm.stopPrank();

        etherfiNodesManagerInstance.fullWithdraw(2);
        console.log("Treasury balance after full withdrawal: ", address(treasuryInstance).balance);
        console.log("NFT holders balance after full withdrawal: ", 0x4B8DF85d5BE4DF1e4D89840E5c7bd3F9D6361D48.balance);
        console.log("Operators balance after full withdrawal: ", 0xB6C9125584A1A28cCafd31056D4aF29014862536.balance);
    }
}