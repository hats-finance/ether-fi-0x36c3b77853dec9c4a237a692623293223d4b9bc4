// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Treasury.sol";
import "../src/NodeOperatorManager.sol";
import "../src/EtherFiNodesManager.sol";
import "../src/EtherFiNode.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/StakingManager.sol";
import "../src/AuctionManager.sol";
import "../src/UUPSProxy.sol";
import "../lib/murky/src/Merkle.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployScript is Script {
    using Strings for string;

    /*---- Storage variables ----*/

    UUPSProxy public auctionManagerProxy;
    UUPSProxy public stakingManagerProxy;
    UUPSProxy public etherFiNodeManagerProxy;
    UUPSProxy public protocolRevenueManagerProxy;
    UUPSProxy public TNFTProxy;
    UUPSProxy public BNFTProxy;

    BNFT public BNFTImplementation;
    BNFT public BNFTInstance;

    TNFT public TNFTImplementation;
    TNFT public TNFTInstance;

    AuctionManager public auctionManagerImplementation;
    AuctionManager public auctionManager;

    StakingManager public stakingManagerImplementation;
    StakingManager public stakingManager;

    ProtocolRevenueManager public protocolRevenueManagerImplementation;
    ProtocolRevenueManager public protocolRevenueManager;

    EtherFiNodesManager public etherFiNodesManagerImplementation;
    EtherFiNodesManager public etherFiNodesManager;

    struct addresses {
        address treasury;
        address nodeOperatorManager;
        address auctionManager;
        address stakingManager;
        address TNFT;
        address BNFT;
        address etherFiNodesManager;
        address protocolRevenueManager;
        address etherFiNode;
    }

    addresses addressStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts
        Treasury treasury = new Treasury();
        NodeOperatorManager nodeOperatorManager = new NodeOperatorManager();

        BNFTImplementation = new BNFT();
        BNFTProxy = new UUPSProxy(address(BNFTImplementation),"");
        BNFTInstance = BNFT(address(BNFTProxy));
        BNFTInstance.initialize();

        TNFTImplementation = new TNFT();
        TNFTProxy = new UUPSProxy(address(TNFTImplementation),"");
        TNFTInstance = TNFT(address(TNFTProxy));
        TNFTInstance.initialize();

        auctionManagerImplementation = new AuctionManager();
        auctionManagerProxy = new UUPSProxy(address(auctionManagerImplementation),"");
        auctionManager = AuctionManager(address(auctionManagerProxy));
        auctionManager.initialize(address(nodeOperatorManager));

        stakingManagerImplementation = new StakingManager();
        stakingManagerProxy = new UUPSProxy(address(stakingManagerImplementation),"");
        stakingManager = StakingManager(address(stakingManagerProxy));
        stakingManager.initialize(address(auctionManager), address(TNFTInstance), address(BNFTInstance));

        protocolRevenueManagerImplementation = new ProtocolRevenueManager();
        protocolRevenueManagerProxy = new UUPSProxy(address(protocolRevenueManagerImplementation),"");
        protocolRevenueManager = ProtocolRevenueManager(payable(address(protocolRevenueManagerProxy)));
        protocolRevenueManager.initialize();

        etherFiNodesManagerImplementation = new EtherFiNodesManager();
        etherFiNodeManagerProxy = new UUPSProxy(address(etherFiNodesManagerImplementation),"");
        etherFiNodesManager = EtherFiNodesManager(payable(address(etherFiNodeManagerProxy)));
        etherFiNodesManager.initialize(
            address(treasury),
            address(auctionManager),
            address(stakingManager),
            address(TNFTInstance),
            address(BNFTInstance),
            address(protocolRevenueManager)
        );

        EtherFiNode etherFiNode = new EtherFiNode();
        
        // Setup dependencies
        nodeOperatorManager.setAuctionContractAddress(address(auctionManager));
        auctionManager.setStakingManagerContractAddress(address(stakingManager));
        auctionManager.setProtocolRevenueManager(address(protocolRevenueManager));
        protocolRevenueManager.setAuctionManagerAddress(address(auctionManager));
        protocolRevenueManager.setEtherFiNodesManagerAddress(address(etherFiNodesManager));
        stakingManager.setEtherFiNodesManagerAddress(address(etherFiNodesManager));
        stakingManager.registerEtherFiNodeImplementationContract(address(etherFiNode));

        vm.stopBroadcast();

        addressStruct = addresses({
            treasury: address(treasury),
            nodeOperatorManager: address(nodeOperatorManager),
            auctionManager: address(auctionManager),
            stakingManager: address(stakingManager),
            TNFT: address(TNFTInstance),
            BNFT: address(BNFTInstance),
            etherFiNodesManager: address(etherFiNodesManager),
            protocolRevenueManager: address(protocolRevenueManager),
            etherFiNode: address(etherFiNode)
        });

        writeVersionFile();
    }

    function _stringToUint(
        string memory numString
    ) internal pure returns (uint256) {
        uint256 val = 0;
        bytes memory stringBytes = bytes(numString);
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint256 exp = stringBytes.length - i;
            bytes1 ival = stringBytes[i];
            uint8 uval = uint8(ival);
            uint256 jval = uval - uint256(0x30);

            val += (uint256(jval) * (10 ** (exp - 1)));
        }
        return val;
    }

    function writeVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine("release/logs/EtherFiSuite/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/EtherFiSuite/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/EtherFiSuite/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nTreasury: ",
                    Strings.toHexString(addressStruct.treasury),
                    "\nNode Operator Key Manager: ",
                    Strings.toHexString(addressStruct.nodeOperatorManager),
                    "\nAuctionManager: ",
                    Strings.toHexString(addressStruct.auctionManager),
                    "\nStakingManager: ",
                    Strings.toHexString(addressStruct.stakingManager),
                    "\nEtherFi Node Manager: ",
                    Strings.toHexString(addressStruct.etherFiNodesManager),
                    "\nProtocol Revenue Manager: ",
                    Strings.toHexString(addressStruct.protocolRevenueManager),
                    "\nTNFT: ",
                    Strings.toHexString(addressStruct.TNFT),
                    "\nBNFT: ",
                    Strings.toHexString(addressStruct.BNFT)
                )
            )
        );
    }
}
