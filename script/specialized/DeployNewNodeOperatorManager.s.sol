// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/NodeOperatorManager.sol";
import "../../src/AuctionManager.sol";
import "../../src/helpers/AddressProvider.sol";
import "../../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployNewNodeOperatorManagerScript is Script {
    using Strings for string;
        
    UUPSProxy public nodeOperatorManagerProxy;

    NodeOperatorManager public nodeOperatorManagerImplementation;
    NodeOperatorManager public nodeOperatorManagerInstance;

    AddressProvider public addressProvider;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);

        address AuctionManagerProxyAddress = addressProvider.getContractAddress("AuctionManager");
        address phaseOneNodeOperator = addressProvider.getContractAddress("NodeOperatorManager");

        // MAINNET
        address[] memory operators = new address[](2);
        operators[0] = 0x2Fc348E6505BA471EB21bFe7a50298fd1f02DBEA;
        operators[1] = 0xD0d7F8a5a86d8271ff87ff24145Cf40CEa9F7A39;

        bytes[] memory hashes = new bytes[](2);
        uint64[] memory totalKeys = new uint64[](2);
        uint64[] memory keysUsed = new uint64[](2);

        vm.startBroadcast(deployerPrivateKey);

        for(uint256 i = 0; i < operators.length; i++) {
            (uint64 totalKeysLocal, uint64 keysUsedLocal, bytes memory ipfsHash) = NodeOperatorManager(phaseOneNodeOperator).addressToOperatorData(operators[i]);
            hashes[i] = ipfsHash;
            totalKeys[i] = totalKeysLocal;
            keysUsed[i] = keysUsedLocal;
        }

        nodeOperatorManagerImplementation = new NodeOperatorManager();
        nodeOperatorManagerProxy = new UUPSProxy(address(nodeOperatorManagerImplementation), "");
        nodeOperatorManagerInstance = NodeOperatorManager(address(nodeOperatorManagerProxy));
        nodeOperatorManagerInstance.initialize();

        console.log("New address:", address(nodeOperatorManagerInstance));

        NodeOperatorManager(nodeOperatorManagerInstance).updateAdmin(0xD0d7F8a5a86d8271ff87ff24145Cf40CEa9F7A39, true);
        NodeOperatorManager(nodeOperatorManagerInstance).batchMigrateNodeOperator(operators, hashes, totalKeys, keysUsed);

        AuctionManager(AuctionManagerProxyAddress).updateNodeOperatorManager(address(nodeOperatorManagerInstance));
        
        if (addressProvider.getContractAddress("NodeOperatorManager") != address(nodeOperatorManagerInstance)) {
            addressProvider.removeContract("NodeOperatorManager");
        }
        addressProvider.addContract(address(nodeOperatorManagerInstance), "NodeOperatorManager");

        vm.stopBroadcast();
    }
}
