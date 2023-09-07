// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/NodeOperatorManager.sol";
import "../../src/helpers/AddressProvider.sol";

contract MigrateNodeOperatorManager is Script {
        
    AddressProvider public addressProvider;
    address public phaseOneNodeOperator;
    address public phaseTwoNodeOperator;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        phaseOneNodeOperator = vm.envAddress("PHASE_ONE_NODE_OPERATOR");
        phaseTwoNodeOperator = addressProvider.getContractAddress("NodeOperatorManager");

        // MAINNET
        address[] memory operators = new address[](7);
        operators[0] = 0x78cA32Ac90D7F99225a3B9288D561E0cB3744899;
        operators[1] = 0x3f95F8f6222F6D97b47122372D60117ab386C48F;
        operators[2] = 0x00a16D2572573DC9E26e2d267f2270cddAC9218B;
        operators[3] = 0xB8db44e12eacc48F7C2224a248c8990289556fAe;
        operators[4] = 0xd624FEfF4b4E77486B544c93A30794CA4B3f10A2;
        operators[5] = 0x6916487F0c4553B9EE2f401847B6C58341B76991;
        operators[6] = 0x7C0576343975A1360CEb91238e7B7985B8d71BF4;

        bytes[] memory hashes = new bytes[](7);
        uint64[] memory totalKeys = new uint64[](7);
        uint64[] memory keysUsed = new uint64[](7);

        vm.startBroadcast(deployerPrivateKey);

        for(uint256 x = 0; x < operators.length; x++) {
            (uint64 totalKeysLocal, uint64 keysUsedLocal, bytes memory ipfsHash) = NodeOperatorManager(phaseOneNodeOperator).addressToOperatorData(operators[x]);
            hashes[x] = ipfsHash;
            totalKeys[x] = totalKeysLocal;
            keysUsed[x] = keysUsedLocal;
        }

        NodeOperatorManager(phaseTwoNodeOperator).batchMigrateNodeOperator(operators, hashes, totalKeys, keysUsed);

        vm.stopBroadcast();
    }
}
