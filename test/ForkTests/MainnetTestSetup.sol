pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../src/interfaces/IStakingManager.sol";
import "../../src/interfaces/IEtherFiNode.sol";
import "../../src/EtherFiNodesManager.sol";
import "../../src/StakingManager.sol";
import "../../src/NodeOperatorManager.sol";
import "../../src/RegulationsManager.sol";
import "../../src/AuctionManager.sol";
import "../../src/ProtocolRevenueManager.sol";
import "../../src/BNFT.sol";
import "../../src/TNFT.sol";
import "../../src/Treasury.sol";
import "../../src/EtherFiNode.sol";
import "../../src/LiquidityPool.sol";
import "../../src/EETH.sol";
import "../../src/WeETH.sol";
import "../../src/MembershipManager.sol";
import "../../src/MembershipNFT.sol";
import "../../src/EarlyAdopterPool.sol";
import "../../src/TVLOracle.sol";
import "../../src/UUPSProxy.sol";
import "../../src/NFTExchange.sol";
import "../../src/helpers/AddressProvider.sol";
import "../DepositDataGeneration.sol";
import "../DepositContract.sol";
import "../Attacker.sol";
import "../../lib/murky/src/Merkle.sol";
import "../TestERC20.sol";

contract MainnetTestSetup is Test {

    AddressProvider public addressProviderInstance; 
    EtherFiNodesManager public etherfiNodesManagerInstance;
    StakingManager public stakingManagerInstance;
    NodeOperatorManager public nodeOperatorManagerInstance;
    RegulationsManager public regulationsManagerInstance;
    AuctionManager public auctionManagerInstance;
    ProtocolRevenueManager public protocolRevenueManagerInstance;
    BNFT public bnftInstance;
    TNFT public tnftInstance;
    Treasury public treasuryInstance;
    LiquidityPool public liquidityPoolInstance;
    EETH public eETHInstance;
    WeETH public weETHInstance;
    MembershipManager public membershipManagerInstance;
    MembershipNFT public membershipNFTInstance;
    EarlyAdopterPool public earlyAdopterPoolInstance;
    NFTExchange public nftExchangeInstance;

    uint256 constant public kwei = 10 ** 3;
    bytes _ipfsHash = "ipfsHash";

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);

    function setUpTests() internal {

        addressProviderInstance = AddressProvider(vm.envAddress("CONTRACT_REGISTRY"));
        etherfiNodesManagerInstance = EtherFiNodesManager(payable(addressProviderInstance.getContractAddress("EtherFiNodesManager")));
        stakingManagerInstance = StakingManager(addressProviderInstance.getContractAddress("StakingManager"));
        nodeOperatorManagerInstance = NodeOperatorManager(addressProviderInstance.getContractAddress("NodeOperatorManager"));
        regulationsManagerInstance = RegulationsManager(addressProviderInstance.getContractAddress("RegulationsManager"));
        auctionManagerInstance = AuctionManager(addressProviderInstance.getContractAddress("AuctionManager"));
        protocolRevenueManagerInstance = ProtocolRevenueManager(payable(addressProviderInstance.getContractAddress("ProtocolRevenueManager")));
        bnftInstance = BNFT(addressProviderInstance.getContractAddress("BNFT"));
        tnftInstance = TNFT(addressProviderInstance.getContractAddress("TNFT"));
        treasuryInstance = Treasury(payable(addressProviderInstance.getContractAddress("Treasury")));
        liquidityPoolInstance = LiquidityPool(payable(addressProviderInstance.getContractAddress("LiquidityPool")));
        eETHInstance = EETH(addressProviderInstance.getContractAddress("EETH"));
        weETHInstance = WeETH(addressProviderInstance.getContractAddress("WeETH"));
        membershipManagerInstance = MembershipManager(payable(addressProviderInstance.getContractAddress("MembershipManager")));
        membershipNFTInstance = MembershipNFT(addressProviderInstance.getContractAddress("MembershipNFT"));
        earlyAdopterPoolInstance = EarlyAdopterPool(payable(addressProviderInstance.getContractAddress("EarlyAdopterPool")));
        nftExchangeInstance = NFTExchange(addressProviderInstance.getContractAddress("NFTExchange"));
    }

}