// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/MembershipManager.sol";
import "../../../src/MembershipNFT.sol";
import "../../../src/EtherFiNodesManager.sol";
import "../../../src/WeETH.sol";
import "../../../src/EETH.sol";
import "../../../src/NFTExchange.sol";
import "../../../src/LiquidityPool.sol";
import "../../../src/ContractRegistry.sol";
import "../../../src/RegulationsManager.sol";
import "../../../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployPhaseOnePointFiveScript is Script {
    using Strings for string;

    /*---- Storage variables ----*/

    UUPSProxy public membershipManagerProxy;
    UUPSProxy public membershipNFTProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public regulationsManagerProxy;
    UUPSProxy public nftExchangeProxy;

    MembershipManager public membershipManagerImplementation;
    MembershipManager public membershipManager;

    MembershipNFT public membershipNFTImplementation;
    MembershipNFT public membershipNFT;

    WeETH public weETHImplementation;
    WeETH public weETH;

    EETH public eETHImplementation;
    EETH public eETH;

    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPool;

    RegulationsManager public regulationsManagerImplementation;
    RegulationsManager public regulationsManager;

    NFTExchange public nftExchangeImplementation;
    NFTExchange public nftExchange;

    ContractRegistry public contractRegistry;

    struct suiteAddresses {
        address weETH;
        address membershipManager;
        address membershipNFT;
        address eETH;
        address liquidityPool;
        address regulationsManager;
        address nftExchange;
    }

    suiteAddresses suiteAddressesStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32[] memory emptyProof;
        
        address contractRegistryAddress = vm.envAddress("CONTRACT_REGISTRY");
        contractRegistry = ContractRegistry(contractRegistryAddress);

        address stakingManagerProxyAddress = contractRegistry.getProxyAddress("Staking Manager");
        address etherFiNodesManagerProxyAddress = contractRegistry.getProxyAddress("EtherFi Nodes Manager");
        address treasury = contractRegistry.getImplementationAddress("Treasury");
        address protocolRevenueManagerProxy = contractRegistry.getProxyAddress("Protocol Revenue Manager");
        address tnft = contractRegistry.getProxyAddress("TNFT");
        address admin = vm.envAddress("ADMIN");

        bytes32 initialHash = vm.envBytes32("INITIAL_HASH");

        string memory baseURI = vm.envString("BASE_URI");

        // Deploy contracts
        regulationsManagerImplementation = new RegulationsManager();
        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation),"");
        regulationsManager = RegulationsManager(address(regulationsManagerProxy));
        regulationsManager.initialize();
        contractRegistry.addContract(address(regulationsManagerProxy), address(regulationsManager), "Regulations Manager", 0);

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation),"");
        liquidityPool = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPool.initialize(address(regulationsManager));
        liquidityPool.setTnft(tnft);
        liquidityPool.setStakingManager(stakingManagerProxyAddress);
        liquidityPool.setEtherFiNodesManager(etherFiNodesManagerProxyAddress);
        contractRegistry.addContract(address(liquidityPoolProxy), address(liquidityPool), "Liquidity Pool", 0);

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation),"");
        eETH = EETH(address(eETHProxy));
        eETH.initialize(address(liquidityPool));
        contractRegistry.addContract(address(eETHProxy), address(eETH), "eETH", 0);

        membershipNFTImplementation = new MembershipNFT();
        membershipNFTProxy = new UUPSProxy(address(membershipNFTImplementation),"");
        membershipNFT = MembershipNFT(payable(address(membershipNFTProxy)));
        membershipNFT.initialize(baseURI);
        contractRegistry.addContract(address(membershipNFTProxy), address(membershipNFT), "Membership NFT", 0);

        membershipManagerImplementation = new MembershipManager();
        membershipManagerProxy = new UUPSProxy(address(membershipManagerImplementation),"");
        membershipManager = MembershipManager(payable(address(membershipManagerProxy)));
        membershipManager.initialize(address(eETH), address(liquidityPool), address(membershipNFT), treasury, protocolRevenueManagerProxy);
        contractRegistry.addContract(address(membershipManagerProxy), address(membershipManager), "Membership Manager", 0);

        weETHImplementation = new WeETH();
        weETHProxy = new UUPSProxy(address(weETHImplementation),"");
        weETH = WeETH(address(weETHProxy));
        weETH.initialize(address(liquidityPool), address(eETH));
        contractRegistry.addContract(address(weETHProxy), address(weETH), "weETH", 0);

        nftExchangeImplementation = new NFTExchange();
        nftExchangeProxy = new UUPSProxy(address(nftExchangeImplementation),"");
        nftExchange = NFTExchange(address(nftExchangeProxy));
        nftExchange.initialize(tnft, address(membershipNFT), address(etherFiNodesManagerProxyAddress));
        contractRegistry.addContract(address(nftExchangeProxy), address(nftExchange), "NFT Exchange", 0);

        // Setup dependencies
        setUpAdmins(admin);

        liquidityPool.setTokenAddress(address(eETH));
        liquidityPool.setMembershipManager(address(membershipManager));
        regulationsManager.initializeNewWhitelist(initialHash);
        regulationsManager.confirmEligibility(initialHash);
        membershipNFT.setMembershipManager(address(membershipManager));
        membershipManager.setTopUpCooltimePeriod(28 days);
        membershipManager.setFeeSplits(0, 100);

        initializeTiers();
        //membershipManager.wrapEthBatch{value: 9.3 ether}(31, 0.3 ether, 0, emptyProof);
        //membershipManager.wrapEthBatch{value: 6.9 ether}(69, 0.1 ether, 0, emptyProof);
        membershipManager.pauseContract();
        
        contractRegistry.setOwner(0xD0d7F8a5a86d8271ff87ff24145Cf40CEa9F7A39);
        vm.stopBroadcast();

        suiteAddressesStruct = suiteAddresses({
            weETH: address(weETH),
            membershipNFT: address(membershipNFT),
            membershipManager: address(membershipManager),
            eETH: address(eETH),
            liquidityPool: address(liquidityPool),
            regulationsManager: address(regulationsManager),
            nftExchange: address(nftExchange)
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
        string memory versionString = vm.readLine("release/logs/PhaseOnePointFive/goerli/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/PhaseOnePointFive/goerli/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/PhaseOnePointFive/goerli/",
                    Strings.toString(version),
                    ".release"
                )
            ),
            string(
                abi.encodePacked(
                    Strings.toString(version),
                    "\nWeETH: ",
                    Strings.toHexString(suiteAddressesStruct.weETH),
                    "\nMembershipManager: ",
                    Strings.toHexString(suiteAddressesStruct.membershipManager),
                    "\nMembershipNFT: ",
                    Strings.toHexString(suiteAddressesStruct.membershipNFT),
                    "\nEETH: ",
                    Strings.toHexString(suiteAddressesStruct.eETH),
                    "\nLiquidity Pool: ",
                    Strings.toHexString(suiteAddressesStruct.liquidityPool),
                    "\nRegulations Manager: ",
                    Strings.toHexString(suiteAddressesStruct.regulationsManager),
                    "\nNFT Exchange: ",
                    Strings.toHexString(suiteAddressesStruct.nftExchange)
                )
            )
        );
    }

    function setUpAdmins(address _admin) internal {
        liquidityPool.updateAdmin(_admin);
        regulationsManager.updateAdmin(_admin);
        membershipManager.updateAdmin(_admin);
        membershipNFT.updateAdmin(_admin);
        nftExchange.updateAdmin(_admin);
    }

    function initializeTiers() internal {
        membershipManager.addNewTier(0, 1);
        membershipManager.addNewTier(672, 2);
        membershipManager.addNewTier(2016, 3);
        membershipManager.addNewTier(4704, 4);
    }
}
