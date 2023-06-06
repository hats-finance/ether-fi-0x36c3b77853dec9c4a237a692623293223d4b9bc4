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
    UUPSProxy public membershipNFTProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public regulationsManagerProxy;

    MeETH public meETHImplementation;
    MeETH public meETH;

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

    struct suiteAddresses {
        address weETH;
        address meETH;
        address membershipNFT;
        address eETH;
        address liquidityPool;
        address regulationsManager;
    }

    suiteAddresses suiteAddressesStruct;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address stakingManagerProxyAddress = vm.envAddress("STAKING_MANAGER_PROXY_ADDRESS");
        address etherFiNodesManagerProxyAddress = vm.envAddress("ETHERFI_NODES_MANAGER_PROXY_ADDRESS");
        bytes32 initialHash = vm.envBytes32("INITIAL_HASH");

        string memory baseURI = vm.envString("BASE_URI");

        // Deploy contracts

        regulationsManagerImplementation = new RegulationsManager();
        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation),"");
        regulationsManager = RegulationsManager(address(regulationsManagerProxy));
        regulationsManager.initialize();

        liquidityPoolImplementation = new LiquidityPool();
        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation),"");
        liquidityPool = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPool.initialize(address(regulationsManager));

        eETHImplementation = new EETH();
        eETHProxy = new UUPSProxy(address(eETHImplementation),"");
        eETH = EETH(address(eETHProxy));
        eETH.initialize(address(liquidityPool));

        membershipNFTImplementation = new MembershipNFT();
        membershipNFTProxy = new UUPSProxy(address(membershipNFTImplementation),"");
        membershipNFT = MembershipNFT(payable(address(membershipNFTProxy)));
        membershipNFT.initialize(baseURI);

        meETHImplementation = new MeETH();
        meETHProxy = new UUPSProxy(address(meETHImplementation),"");
        meETH = MeETH(payable(address(meETHProxy)));
        meETH.initialize(address(eETH), address(liquidityPool), address(membershipNFT));

        weETHImplementation = new WeETH();
        weETHProxy = new UUPSProxy(address(weETHImplementation),"");
        weETH = WeETH(address(weETHProxy));
        weETH.initialize(address(liquidityPool), address(eETH));

        // Setup dependencies
        regulationsManager.initializeNewWhitelist(initialHash);

        liquidityPool.setTokenAddress(address(eETH));
        liquidityPool.setStakingManager(stakingManagerProxyAddress);
        liquidityPool.setEtherFiNodesManager(etherFiNodesManagerProxyAddress);
        liquidityPool.setMeETH(address(meETH));
        membershipNFT.setMeETH(address(meETH));

        vm.stopBroadcast();

        suiteAddressesStruct = suiteAddresses({
            weETH: address(weETH),
            membershipNFT: address(membershipNFT),
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
                    "\nMeETH: ",
                    Strings.toHexString(suiteAddressesStruct.meETH),
                    "\nMembershipNFT: ",
                    Strings.toHexString(suiteAddressesStruct.membershipNFT),
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
