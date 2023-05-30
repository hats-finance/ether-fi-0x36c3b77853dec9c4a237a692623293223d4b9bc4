// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../../src/MeETH.sol";
import "../../../src/WeETH.sol";
import "../../../src/EETH.sol";
import "../../../src/LiquidityPool.sol";
import "../../../src/RegulationsManager.sol";
import "../../../src/UUPSProxy.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DeployPhaseOnePointFiveScript is Script {
    using Strings for string;

    /*---- Storage variables ----*/

    UUPSProxy public meETHProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public regulationsManagerProxy;

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

    struct suiteAddresses {
        address weETH;
        address meETH;
        address eETH;
        address liquidityPool;
        address regulationsManager;
    }

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

        // Setup dependencies
        regulationsManager.initializeNewWhitelist(initialHash);

        liquidityPool.setTokenAddress(eETHProxyAddress);
        liquidityPool.setStakingManager(stakingManagerProxyAddress);
        liquidityPool.setEtherFiNodesManager(etherFiNodesManagerProxyAddress);
        liquidityPool.setMeETH(address(meETH));

        vm.stopBroadcast();

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
        string memory versionString = vm.readLine("release/logs/PhaseOnePointFive/mainnet/version.txt");

        // Cast string to uint256
        uint256 version = _stringToUint(versionString);

        version++;

        // Overwrites the version.txt file with incremented version
        vm.writeFile(
            "release/logs/PhaseOnePointFive/mainnet/version.txt",
            string(abi.encodePacked(Strings.toString(version)))
        );

        // Writes the data to .release file
        vm.writeFile(
            string(
                abi.encodePacked(
                    "release/logs/PhaseOnePointFive/mainnet/",
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
