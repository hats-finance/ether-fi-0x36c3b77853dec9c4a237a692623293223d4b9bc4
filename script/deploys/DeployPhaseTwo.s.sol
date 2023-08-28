// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../../src/UUPSProxy.sol";
import "../../src/EtherFiOracle.sol";
import "../../src/EtherFiAdmin.sol";
import "../../src/WithdrawRequestNFT.sol";
import "../../src/helpers/AddressProvider.sol";
import "../../src/UUPSProxy.sol";

contract DeployPhaseTwoScript is Script {
    UUPSProxy public etherFiOracleProxy;
    EtherFiOracle public etherFiOracleInstance;
    EtherFiOracle public etherFiOracleImplementation;

    UUPSProxy public etherFiAdminProxy;
    EtherFiAdmin public etherFiAdminInstance;
    EtherFiAdmin public etherFiAdminImplementation;

    UUPSProxy public withdrawRequestNftProxy;
    WithdrawRequestNFT public withdrawRequestNftInstance;
    WithdrawRequestNFT public withdrawRequestNftImplementation;

    AddressProvider public addressProvider;

    address addressProviderAddress;
    address etherFiOracleAddress;
    address stakingManagerAddress;
    address auctionAddress;
    address managerAddress;
    address liquidityPoolAddress;
    address eEthAddress;
    address membershipManagerAddress;
    address withdrawRequestNFTAddress;

    uint32 beacon_genesis_time;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");    
        beacon_genesis_time = uint32(vm.envUint("BEACON_GENESIS_TIME"));
        addressProviderAddress = vm.envAddress("CONTRACT_REGISTRY");
        addressProvider = AddressProvider(addressProviderAddress);
        
        vm.startBroadcast(deployerPrivateKey);

        deploy_WithdrawRequestNFT();

        deploy_EtherFiOracle();

        deploy_EtherFiAdmin();

        vm.stopBroadcast();
    }

    function retrieve_contract_addresses() internal {
        // Retrieve the addresses of the contracts that have already been deployed
        etherFiOracleAddress = addressProvider.getContractAddress("EtherFiOracle");
        stakingManagerAddress = addressProvider.getContractAddress("StakingManager");
        auctionAddress = addressProvider.getContractAddress("AuctionManager");
        managerAddress = addressProvider.getContractAddress("EtherFiNodesManager");
        liquidityPoolAddress = addressProvider.getContractAddress("LiquidityPool");
        eEthAddress = addressProvider.getContractAddress("EETH");
        membershipManagerAddress = addressProvider.getContractAddress("MembershipManager");
        withdrawRequestNFTAddress = addressProvider.getContractAddress("WithdrawRequestNFT");
    }

    function deploy_WithdrawRequestNFT() internal {
        if (addressProvider.getContractAddress("WithdrawRequestNFT") != address(0)) {
            addressProvider.removeContract("WithdrawRequestNFT");
        }
        retrieve_contract_addresses();

        withdrawRequestNftImplementation = new WithdrawRequestNFT();
        withdrawRequestNftProxy = new UUPSProxy(address(withdrawRequestNftImplementation), "");
        withdrawRequestNftInstance = WithdrawRequestNFT(payable(withdrawRequestNftProxy));

        withdrawRequestNftInstance.initialize(liquidityPoolAddress, eEthAddress);

        addressProvider.addContract(address(withdrawRequestNftProxy), "WithdrawRequestNFT");
    }

    function deploy_EtherFiOracle() internal {
        if (addressProvider.getContractAddress("EtherFiOracle") != address(0)) {
            addressProvider.removeContract("EtherFiOracle");
        }
        retrieve_contract_addresses();

        etherFiOracleImplementation = new EtherFiOracle();
        etherFiOracleProxy = new UUPSProxy(address(etherFiOracleImplementation), "");
        etherFiOracleInstance = EtherFiOracle(payable(etherFiOracleProxy));

        etherFiOracleInstance.initialize(1, 96, 32, 12, beacon_genesis_time);
        // etherFiOracleInstance.initialize(2, 7200, 12, beacon_genesis_time);
        // 96 slots = 19.2 mins, 7200 slots = 225 epochs = 1day

        addressProvider.addContract(address(etherFiOracleProxy), "EtherFiOracle");
    }

    function deploy_EtherFiAdmin() internal {
        if (addressProvider.getContractAddress("EtherFiAdmin") != address(0)) {
            addressProvider.removeContract("EtherFiAdmin");
        }
        retrieve_contract_addresses();

        etherFiAdminImplementation = new EtherFiAdmin();
        etherFiAdminProxy = new UUPSProxy(address(etherFiAdminImplementation), "");
        etherFiAdminInstance = EtherFiAdmin(payable(etherFiAdminProxy));

        // Retrieve their actuall addresses from AddressProvider using their contract names
        etherFiAdminInstance.initialize(
            etherFiOracleAddress,
            stakingManagerAddress,
            auctionAddress,
            managerAddress,
            liquidityPoolAddress,
            membershipManagerAddress,
            withdrawRequestNFTAddress
        );

        addressProvider.addContract(address(etherFiAdminProxy), "EtherFiAdmin");
    }
}