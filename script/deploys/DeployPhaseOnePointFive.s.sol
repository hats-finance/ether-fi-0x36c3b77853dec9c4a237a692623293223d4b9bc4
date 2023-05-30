// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/Treasury.sol";
import "../../src/NodeOperatorManager.sol";
import "../../src/EtherFiNodesManager.sol";
import "../../src/EtherFiNode.sol";
import "../../src/BNFT.sol";
import "../../src/TNFT.sol";
import "../../src/ProtocolRevenueManager.sol";
import "../../src/StakingManager.sol";
import "../../src/AuctionManager.sol";

import "../../src/MeETH.sol";
import "../../src/WeETH.sol";
import "../../src/EETH.sol";
import "../../src/LiquidityPool.sol";
import "../../src/RegulationsManager.sol";


import "../../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//meETH
//eETH
//liquidityPool
//regulationsManager
//weETH

contract DeployPhaseOnePointFive is Script {
    using Strings for string;

    /*---- Storage variables ----*/

    UUPSProxy public meETHProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public regulationsManagerProxy;

    // UUPSProxy public auctionManagerProxy;
    // UUPSProxy public stakingManagerProxy;
    // UUPSProxy public etherFiNodeManagerProxy;
    // UUPSProxy public protocolRevenueManagerProxy;
    // UUPSProxy public TNFTProxy;
    // UUPSProxy public BNFTProxy;

    // BNFT public BNFTImplementation;
    // BNFT public BNFTInstance;

    // TNFT public TNFTImplementation;
    // TNFT public TNFTInstance;+


    MeETH public meETHImplementation;
    MeETH public meETH;

    WeETH public weETHImplementation;
    WeETH public weETH;

    EETH public eETHImplementation;
    EETH public eETH;

    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPool;

    RegulationsManager public regulationsManagerImplementation;
    RegulationsManager public regulationsManager;


    // AuctionManager public auctionManagerImplementation;
    // AuctionManager public auctionManager;

    // StakingManager public stakingManagerImplementation;
    // StakingManager public stakingManager;

    // ProtocolRevenueManager public protocolRevenueManagerImplementation;
    // ProtocolRevenueManager public protocolRevenueManager;

    // EtherFiNodesManager public etherFiNodesManagerImplementation;
    // EtherFiNodesManager public etherFiNodesManager;

    struct suiteAddresses {
        address weETH;
        address meETH;
        address eETH;
        address liquidityPool;
        address regulationsManager;
    }

    // struct suiteAddresses {
    //     address treasury;
    //     address nodeOperatorManager;
    //     address auctionManager;
    //     address stakingManager;
    //     address TNFT;
    //     address BNFT;
    //     address etherFiNodesManager;
    //     address protocolRevenueManager;
    //     address etherFiNode;
    // }

    suiteAddresses suiteAddressesStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address eETHProxyAddress = vm.envAddress("EETH_PROXY_ADDRESS");
        address liquidityPoolProxyAddress = vm.envAddress("LIQUIDITY_POOL_PROXY_ADDRESS");
        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address etherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        bytes32 initialHash = vm.envBytes32("INITIAL_HASH");

        string memory baseURI = "https:token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json";

        // Deploy contracts
        meETHImplementation = new MeETH();
        meETHProxy = new UUPSProxy(address(meETHImplementation),"");
        meETH = MeETH(payable(address(meETHProxy)));
        meETH.initialize(baseURI, eETHProxyAddress, liquidityPoolProxyAddress);

        weETHImplementation = new WeETH();
        weETHProxy = new UUPSProxy(address(weETHImplementation),"");
        weETH = WeETH(address(weETHProxy));
        weETH.initialize(liquidityPoolProxyAddress, eETHProxyAddress);

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation),"");
        eETH = EETH(address(eETHProxy));
        eETH.initialize(liquidityPoolProxyAddress);

        regulationsManagerImplementation = new RegulationsManager();
        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation),"");
        regulationsManager = RegulationsManager(address(regulationsManagerProxy));
        regulationsManager.initialize();

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation),"");
        liquidityPool = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPool.initialize(address(regulationsManagerProxy));



        // Deploy contracts
        // Treasury treasury = new Treasury();
        // NodeOperatorManager nodeOperatorManager = new NodeOperatorManager();

        // auctionManagerImplementation = new AuctionManager();
        // auctionManagerProxy = new UUPSProxy(address(auctionManagerImplementation),"");
        // auctionManager = AuctionManager(address(auctionManagerProxy));
        // auctionManager.initialize(address(nodeOperatorManager));

        // stakingManagerImplementation = new StakingManager();
        // stakingManagerProxy = new UUPSProxy(address(stakingManagerImplementation),"");
        // stakingManager = StakingManager(address(stakingManagerProxy));
        // stakingManager.initialize(address(auctionManager));

        // BNFTImplementation = new BNFT();
        // BNFTProxy = new UUPSProxy(address(BNFTImplementation),"");
        // BNFTInstance = BNFT(address(BNFTProxy));
        // BNFTInstance.initialize(address(stakingManager));

        // TNFTImplementation = new TNFT();
        // TNFTProxy = new UUPSProxy(address(TNFTImplementation),"");
        // TNFTInstance = TNFT(address(TNFTProxy));
        // TNFTInstance.initialize(address(stakingManager));

        // protocolRevenueManagerImplementation = new ProtocolRevenueManager();
        // protocolRevenueManagerProxy = new UUPSProxy(address(protocolRevenueManagerImplementation),"");
        // protocolRevenueManager = ProtocolRevenueManager(payable(address(protocolRevenueManagerProxy)));
        // protocolRevenueManager.initialize();

        // etherFiNodesManagerImplementation = new EtherFiNodesManager();
        // etherFiNodeManagerProxy = new UUPSProxy(address(etherFiNodesManagerImplementation),"");
        // etherFiNodesManager = EtherFiNodesManager(payable(address(etherFiNodeManagerProxy)));
        // etherFiNodesManager.initialize(
        //     address(treasury),
        //     address(auctionManager),
        //     address(stakingManager),
        //     address(TNFTInstance),
        //     address(BNFTInstance),
        //     address(protocolRevenueManager)
        // );

        // EtherFiNode etherFiNode = new EtherFiNode();

        // Setup dependencies
        regulationsManager.initializeNewWhitelist(initialHash);

        liquidityPool.setTokenAddress(eETHProxyAddress);
        liquidityPool.setStakingManager(stakingManagerProxyAddress);
        liquidityPool.setEtherFiNodesManager(etherFiNodesManagerProxyAddress);
        liquidityPool.setMeETH(address(meETH));

        // Setup dependencies
        // nodeOperatorManager.setAuctionContractAddress(address(auctionManager));

        // auctionManager.setStakingManagerContractAddress(address(stakingManager));
        // auctionManager.setProtocolRevenueManager(address(protocolRevenueManager));

        // protocolRevenueManager.setAuctionManagerAddress(address(auctionManager));
        // protocolRevenueManager.setEtherFiNodesManagerAddress(address(etherFiNodesManager));

        // stakingManager.setEtherFiNodesManagerAddress(address(etherFiNodesManager));
        // stakingManager.registerEtherFiNodeImplementationContract(address(etherFiNode));
        // stakingManager.registerTNFTContract(address(TNFTInstance));
        // stakingManager.registerBNFTContract(address(BNFTInstance));

        vm.stopBroadcast();

        // suiteAddressesStruct = suiteAddresses({
        //     treasury: address(treasury),
        //     nodeOperatorManager: address(nodeOperatorManager),
        //     auctionManager: address(auctionManager),
        //     stakingManager: address(stakingManager),
        //     TNFT: address(TNFTInstance),
        //     BNFT: address(BNFTInstance),
        //     etherFiNodesManager: address(etherFiNodesManager),
        //     protocolRevenueManager: address(protocolRevenueManager),
        //     etherFiNode: address(etherFiNode)
        // });

        suiteAddressesStruct = suiteAddresses({
            weETH: address(weETH),
            meETH: address(meETH),
            eETH: address(eETH),
            liquidityPool: address(liquidityPool),
            regulationsManager: address(regulationsManager)
        });

        writeSuiteVersionFile();
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

    function writeSuiteVersionFile() internal {
        // Read Current version
        string memory versionString = vm.readLine("release/logs/PhaseOnePointFive/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/PhaseOnePointFive/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/PhaseOnePointFive/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nWeETH: ",
                    Strings.toHexString(suiteAddressesStruct.weETH),
                    "\nMeETH: ",
                    Strings.toHexString(suiteAddressesStruct.meETH),
                    "\nEETH: ",
                    Strings.toHexString(suiteAddressesStruct.eETH),
                    "\nLiquidity Pool: ",
                    Strings.toHexString(suiteAddressesStruct.liquidityPool),
                    "\nRegulations Manager: ",
                    Strings.toHexString(suiteAddressesStruct.regulationsManager)
                )
            )
        );
    }
}
