pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/interfaces/IStakingManager.sol";
import "../src/interfaces/IEtherFiNode.sol";
import "../src/EtherFiNodesManager.sol";
import "../src/StakingManager.sol";
import "../src/NodeOperatorManager.sol";
import "../src/RegulationsManager.sol";
import "../src/AuctionManager.sol";
import "../src/ProtocolRevenueManager.sol";
import "../src/BNFT.sol";
import "../src/TNFT.sol";
import "../src/Treasury.sol";
import "../src/EtherFiNode.sol";
import "../src/LiquidityPool.sol";
import "../src/EETH.sol";
import "../src/WeETH.sol";
import "../src/MembershipManager.sol";
import "../src/MembershipNFT.sol";
import "../src/EarlyAdopterPool.sol";
import "../src/TVLOracle.sol";
import "../src/UUPSProxy.sol";
import "../src/WithdrawRequestNFT.sol";
import "../src/NFTExchange.sol";
import "../src/helpers/AddressProvider.sol";
import "./DepositDataGeneration.sol";
import "./DepositContract.sol";
import "./Attacker.sol";
import "../lib/murky/src/Merkle.sol";
import "./TestERC20.sol";

import "../src/MembershipManagerV0.sol";
import "../src/EtherFiOracle.sol";
import "../src/EtherFiAdmin.sol";


contract TestSetup is Test {
    uint256 public constant kwei = 10 ** 3;
    uint256 public slippageLimit = 50;

    TestERC20 public rETH;
    TestERC20 public wstETH;
    TestERC20 public sfrxEth;
    TestERC20 public cbEth;

    UUPSProxy public auctionManagerProxy;
    UUPSProxy public stakingManagerProxy;
    UUPSProxy public etherFiNodeManagerProxy;
    UUPSProxy public protocolRevenueManagerProxy;
    UUPSProxy public TNFTProxy;
    UUPSProxy public BNFTProxy;
    UUPSProxy public liquidityPoolProxy;
    UUPSProxy public eETHProxy;
    UUPSProxy public regulationsManagerProxy;
    UUPSProxy public weETHProxy;
    UUPSProxy public nodeOperatorManagerProxy;
    UUPSProxy public membershipManagerProxy;
    UUPSProxy public membershipNftProxy;
    UUPSProxy public nftExchangeProxy;
    UUPSProxy public withdrawRequestNFTProxy;
    UUPSProxy public etherFiOracleProxy;
    UUPSProxy public etherFiAdminProxy;

    DepositDataGeneration public depGen;
    IDepositContract public depositContractEth2;

    DepositContract public mockDepositContractEth2;

    StakingManager public stakingManagerInstance;
    StakingManager public stakingManagerImplementation;

    AuctionManager public auctionImplementation;
    AuctionManager public auctionInstance;

    ProtocolRevenueManager public protocolRevenueManagerInstance;
    ProtocolRevenueManager public protocolRevenueManagerImplementation;

    EtherFiNodesManager public managerInstance;
    EtherFiNodesManager public managerImplementation;

    RegulationsManager public regulationsManagerInstance;
    RegulationsManager public regulationsManagerImplementation;

    EarlyAdopterPool public earlyAdopterPoolInstance;
    AddressProvider public addressProviderInstance;

    TNFT public TNFTImplementation;
    TNFT public TNFTInstance;

    BNFT public BNFTImplementation;
    BNFT public BNFTInstance;

    LiquidityPool public liquidityPoolImplementation;
    LiquidityPool public liquidityPoolInstance;

    EETH public eETHImplementation;
    EETH public eETHInstance;

    WeETH public weEthImplementation;
    WeETH public weEthInstance;

    MembershipManagerV0 public membershipManagerImplementation;
    MembershipManagerV0 public membershipManagerInstance;

    MembershipManager public membershipManagerV1Implementation;
    MembershipManager public membershipManagerV1Instance;

    MembershipNFT public membershipNftImplementation;
    MembershipNFT public membershipNftInstance;

    WithdrawRequestNFT public withdrawRequestNFTImplementation;
    WithdrawRequestNFT public withdrawRequestNFTInstance;

    NFTExchange public nftExchangeImplementation;
    NFTExchange public nftExchangeInstance;

    NodeOperatorManager public nodeOperatorManagerImplementation;
    NodeOperatorManager public nodeOperatorManagerInstance;

    EtherFiOracle public etherFiOracleImplementation;
    EtherFiOracle public etherFiOracleInstance;

    EtherFiAdmin public etherFiAdminImplementation;
    EtherFiAdmin public etherFiAdminInstance;

    EtherFiNode public node;
    Treasury public treasuryInstance;

    Attacker public attacker;
    RevertAttacker public revertAttacker;
    GasDrainAttacker public gasDrainAttacker;
    NoAttacker public noAttacker;

    TVLOracle tvlOracle;

    Merkle merkle;
    bytes32 root;

    Merkle merkleMigration;
    bytes32 rootMigration;

    Merkle merkleMigration2;
    bytes32 rootMigration2;

    uint64[] public requiredEapPointsPerEapDeposit;

    bytes32 termsAndConditionsHash = keccak256("TERMS AND CONDITIONS");

    bytes32[] public whiteListedAddresses;
    bytes32[] public dataForVerification;
    bytes32[] public dataForVerification2;

    IStakingManager.DepositData public test_data;
    IStakingManager.DepositData public test_data_2;

    address owner = vm.addr(1);
    address alice = vm.addr(2);
    address bob = vm.addr(3);
    address chad = vm.addr(4);
    address dan = vm.addr(5);
    address elvis = vm.addr(6);
    address greg = vm.addr(7);
    address henry = vm.addr(8);
    address liquidityPool = vm.addr(9);
    address shonee = vm.addr(1200);
    address jess = vm.addr(1201);

    address[] public actors;
    address[] public bnftHoldersArray;
    uint256[] public whitelistIndices;

    bytes aliceIPFSHash = "AliceIPFS";
    bytes _ipfsHash = "ipfsHash";

    bytes32 zeroRoot = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32[] zeroProof;

    IEtherFiOracle.OracleReport reportAtPeriod2A;
    IEtherFiOracle.OracleReport reportAtPeriod2B;
    IEtherFiOracle.OracleReport reportAtPeriod2C;
    IEtherFiOracle.OracleReport reportAtPeriod3;
    IEtherFiOracle.OracleReport reportAtPeriod3A;
    IEtherFiOracle.OracleReport reportAtPeriod3B;
    IEtherFiOracle.OracleReport reportAtPeriod4;

    int256 slotsPerEpoch = 32;
    int256 secondsPerSlot = 12;

    function setUpTests() internal {
        vm.startPrank(owner);

        // Deploy Contracts and Proxies
        treasuryInstance = new Treasury();

        nodeOperatorManagerImplementation = new NodeOperatorManager();
        nodeOperatorManagerProxy = new UUPSProxy(address(nodeOperatorManagerImplementation), "");
        nodeOperatorManagerInstance = NodeOperatorManager(address(nodeOperatorManagerProxy));
        nodeOperatorManagerInstance.initialize();
        nodeOperatorManagerInstance.updateAdmin(alice);

        auctionImplementation = new AuctionManager();
        auctionManagerProxy = new UUPSProxy(address(auctionImplementation), "");
        auctionInstance = AuctionManager(address(auctionManagerProxy));
        auctionInstance.initialize(address(nodeOperatorManagerInstance));
        auctionInstance.updateAdmin(alice);

        stakingManagerImplementation = new StakingManager();
        stakingManagerProxy = new UUPSProxy(address(stakingManagerImplementation), "");
        stakingManagerInstance = StakingManager(address(stakingManagerProxy));
        stakingManagerInstance.initialize(address(auctionInstance));
        stakingManagerInstance.updateAdmin(alice);

        TNFTImplementation = new TNFT();
        TNFTProxy = new UUPSProxy(address(TNFTImplementation), "");
        TNFTInstance = TNFT(address(TNFTProxy));
        TNFTInstance.initialize(address(stakingManagerInstance));

        BNFTImplementation = new BNFT();
        BNFTProxy = new UUPSProxy(address(BNFTImplementation), "");
        BNFTInstance = BNFT(address(BNFTProxy));
        BNFTInstance.initialize(address(stakingManagerInstance));

        protocolRevenueManagerImplementation = new ProtocolRevenueManager();
        protocolRevenueManagerProxy = new UUPSProxy(address(protocolRevenueManagerImplementation), "");
        protocolRevenueManagerInstance = ProtocolRevenueManager(payable(address(protocolRevenueManagerProxy)));
        protocolRevenueManagerInstance.initialize();
        protocolRevenueManagerInstance.updateAdmin(alice);

        managerImplementation = new EtherFiNodesManager();
        etherFiNodeManagerProxy = new UUPSProxy(address(managerImplementation), "");
        managerInstance = EtherFiNodesManager(payable(address(etherFiNodeManagerProxy)));
        managerInstance.initialize(
            address(treasuryInstance),
            address(auctionInstance),
            address(stakingManagerInstance),
            address(TNFTInstance),
            address(BNFTInstance),
            address(protocolRevenueManagerInstance)
        );
        managerInstance.updateAdmin(alice);

        regulationsManagerImplementation = new RegulationsManager();
        vm.expectRevert("Initializable: contract is already initialized");
        regulationsManagerImplementation.initialize();

        regulationsManagerProxy = new UUPSProxy(address(regulationsManagerImplementation), "");
        regulationsManagerInstance = RegulationsManager(address(regulationsManagerProxy));
        regulationsManagerInstance.initialize();
        regulationsManagerInstance.updateAdmin(alice);

        node = new EtherFiNode();

        rETH = new TestERC20("Rocket Pool ETH", "rETH");
        rETH.mint(alice, 10e18);
        rETH.mint(bob, 10e18);
        cbEth = new TestERC20("Staked ETH", "wstETH");
        cbEth.mint(alice, 10e18);
        cbEth.mint(bob, 10e18);
        wstETH = new TestERC20("Coinbase ETH", "cbEth");
        wstETH.mint(alice, 10e18);
        wstETH.mint(bob, 10e18);
        sfrxEth = new TestERC20("Frax ETH", "sfrxEth");
        sfrxEth.mint(alice, 10e18);
        sfrxEth.mint(bob, 10e18);

        earlyAdopterPoolInstance = new EarlyAdopterPool(
            address(rETH),
            address(wstETH),
            address(sfrxEth),
            address(cbEth)
        );

        addressProviderInstance = new AddressProvider(address(owner));

        liquidityPoolImplementation = new LiquidityPool();
        vm.expectRevert("Initializable: contract is already initialized");
        liquidityPoolImplementation.initialize(address(regulationsManagerInstance));

        liquidityPoolProxy = new UUPSProxy(address(liquidityPoolImplementation),"");
        liquidityPoolInstance = LiquidityPool(payable(address(liquidityPoolProxy)));
        liquidityPoolInstance.initialize(address(regulationsManagerInstance));
        liquidityPoolInstance.setTnft(address(TNFTInstance));
        liquidityPoolInstance.updateAdmin(alice);

        eETHImplementation = new EETH();
        vm.expectRevert("Initializable: contract is already initialized");
        eETHImplementation.initialize(payable(address(liquidityPoolInstance)));

        eETHProxy = new UUPSProxy(address(eETHImplementation), "");
        eETHInstance = EETH(address(eETHProxy));

        vm.expectRevert("No zero addresses");
        eETHInstance.initialize(payable(address(0)));
        eETHInstance.initialize(payable(address(liquidityPoolInstance)));

        weEthImplementation = new WeETH();
        vm.expectRevert("Initializable: contract is already initialized");
        weEthImplementation.initialize(payable(address(liquidityPoolInstance)), address(eETHInstance));

        weETHProxy = new UUPSProxy(address(weEthImplementation), "");
        weEthInstance = WeETH(address(weETHProxy));
        vm.expectRevert("No zero addresses");
        weEthInstance.initialize(address(0), address(eETHInstance));
        vm.expectRevert("No zero addresses");
        weEthInstance.initialize(payable(address(liquidityPoolInstance)), address(0));
        weEthInstance.initialize(payable(address(liquidityPoolInstance)), address(eETHInstance));
        vm.stopPrank();

        vm.prank(alice);
        regulationsManagerInstance.initializeNewWhitelist(termsAndConditionsHash);
        vm.startPrank(owner);

        membershipNftImplementation = new MembershipNFT();
        membershipNftProxy = new UUPSProxy(address(membershipNftImplementation), "");
        membershipNftInstance = MembershipNFT(payable(membershipNftProxy));
        membershipNftInstance.initialize("https://etherfi-cdn/{id}.json");
        membershipNftInstance.updateAdmin(alice);

        withdrawRequestNFTImplementation = new WithdrawRequestNFT();
        withdrawRequestNFTProxy = new UUPSProxy(address(withdrawRequestNFTImplementation), "");
        withdrawRequestNFTInstance = WithdrawRequestNFT(payable(withdrawRequestNFTProxy));
        withdrawRequestNFTInstance.initialize(payable(address(liquidityPoolInstance)), payable(address(eETHInstance)));
        withdrawRequestNFTInstance.updateAdmin(alice);

        liquidityPoolInstance.setWithdrawRequestNFT(address(withdrawRequestNFTInstance));

        membershipManagerImplementation = new MembershipManagerV0();
        membershipManagerProxy = new UUPSProxy(address(membershipManagerImplementation), "");
        membershipManagerInstance = MembershipManagerV0(payable(membershipManagerProxy));
        membershipManagerInstance.initialize(
            address(eETHInstance),
            address(liquidityPoolInstance),
            address(membershipNftInstance),
            address(treasuryInstance),
            address(protocolRevenueManagerInstance)
        );
        membershipManagerInstance.updateAdmin(alice);
        auctionInstance.setMembershipManagerContractAddress(address(membershipManagerInstance));

        etherFiOracleImplementation = new EtherFiOracle();
        etherFiOracleProxy = new UUPSProxy(address(etherFiOracleImplementation), "");
        etherFiOracleInstance = EtherFiOracle(payable(etherFiOracleProxy));
        etherFiOracleInstance.initialize(2, 1024, 32, 12, 1);
        
        vm.stopPrank();

        vm.prank(alice);
        membershipManagerInstance.setTopUpCooltimePeriod(28 days);
        vm.startPrank(owner);

        membershipNftInstance.setMembershipManager(address(membershipManagerInstance));
        membershipNftInstance.setLiquidityPool(address(liquidityPoolInstance));

        tvlOracle = new TVLOracle(alice);

        nftExchangeImplementation = new NFTExchange();
        nftExchangeProxy = new UUPSProxy(address(nftExchangeImplementation), "");
        nftExchangeInstance = NFTExchange(payable(nftExchangeProxy));
        nftExchangeInstance.initialize(address(TNFTInstance), address(membershipNftInstance), address(managerInstance));
        nftExchangeInstance.updateAdmin(alice);

        etherFiAdminImplementation = new EtherFiAdmin();
        etherFiAdminProxy = new UUPSProxy(address(etherFiAdminImplementation), "");
        etherFiAdminInstance = EtherFiAdmin(payable(etherFiAdminProxy));
        etherFiAdminInstance.initialize(
            address(etherFiOracleInstance),
            address(stakingManagerInstance),
            address(auctionInstance),
            address(managerInstance),
            address(liquidityPoolInstance),
            address(membershipManagerInstance),
            address(withdrawRequestNFTInstance)
        );

        uint256[] memory validatorsToApprove = new uint256[](1);
        uint256[] memory validatorsToExit = new uint256[](1);
        uint256[] memory exitedValidators = new uint256[](1);
        uint256[] memory slashedValidators = new uint256[](1);
        uint256[] memory withdrawalRequestsToInvalidate = new uint256[](1);
        reportAtPeriod2A = IEtherFiOracle.OracleReport(1, 0, 1024 - 1, 0, 1024 - 1, 200000, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod2B = IEtherFiOracle.OracleReport(1, 0, 1024 - 1, 0, 1024 - 1, 200001, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod2C = IEtherFiOracle.OracleReport(2, 0, 1024 - 1, 0, 1024 - 1, 200001, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod3 = IEtherFiOracle.OracleReport(1, 0, 2048 - 1, 0, 2048 - 1, 200000, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod3A = IEtherFiOracle.OracleReport(1, 0, 2048 - 1, 0, 3 * 1024 - 1, 200000, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod3B = IEtherFiOracle.OracleReport(1, 0, 2048 - 1, 1, 2 * 1024 - 1, 200000, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);
        reportAtPeriod4 = IEtherFiOracle.OracleReport(1, 2 * 1024, 1024 * 3 - 1, 2 * 1024, 3 * 1024 - 1, 200000, validatorsToApprove, validatorsToExit, exitedValidators, slashedValidators, withdrawalRequestsToInvalidate, 1, 80, 20);

        vm.stopPrank();

        // Setup dependencies
        vm.startPrank(alice);
        _setUpNodeOperatorWhitelist();
        vm.stopPrank();

        _merkleSetup();

        vm.startPrank(owner);
        _merkleSetupMigration();

        vm.startPrank(owner);
        _merkleSetupMigration2();

        nodeOperatorManagerInstance.setAuctionContractAddress(address(auctionInstance));

        auctionInstance.setStakingManagerContractAddress(address(stakingManagerInstance));

        protocolRevenueManagerInstance.setAuctionManagerAddress(address(auctionInstance));
        protocolRevenueManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));

        stakingManagerInstance.setEtherFiNodesManagerAddress(address(managerInstance));
        stakingManagerInstance.setLiquidityPoolAddress(address(liquidityPoolInstance));
        stakingManagerInstance.registerEtherFiNodeImplementationContract(address(node));
        stakingManagerInstance.registerTNFTContract(address(TNFTInstance));
        stakingManagerInstance.registerBNFTContract(address(BNFTInstance));

        liquidityPoolInstance.setTokenAddress(address(eETHInstance));
        liquidityPoolInstance.setStakingManager(address(stakingManagerInstance));
        liquidityPoolInstance.setEtherFiNodesManager(address(managerInstance));
        liquidityPoolInstance.setMembershipManager(address(membershipManagerInstance));
        liquidityPoolInstance.updateAdmin(alice);
        liquidityPoolInstance.updateBNftTreasury(owner);

        vm.stopPrank();

        vm.prank(alice);
        liquidityPoolInstance.openEEthLiquidStaking();

        vm.startPrank(owner);

        depGen = new DepositDataGeneration();
        mockDepositContractEth2 = new DepositContract();

        // depositContractEth2 = IDepositContract(0xff50ed3d0ec03aC01D4C79aAd74928BFF48a7b2b); // Goerli testnet deposit contract
        depositContractEth2 = IDepositContract(address(mockDepositContractEth2));
        stakingManagerInstance.registerEth2DepositContract(address(mockDepositContractEth2));

        attacker = new Attacker(address(liquidityPoolInstance));
        revertAttacker = new RevertAttacker();
        gasDrainAttacker = new GasDrainAttacker();
        noAttacker = new NoAttacker();

        vm.stopPrank();

        _initializeMembershipTiers();
        vm.stopPrank();

        _initializePeople();
    }

    function _merkleSetup() internal {
        merkle = new Merkle();

        whiteListedAddresses.push(keccak256(abi.encodePacked(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf)));
        whiteListedAddresses.push(keccak256(abi.encodePacked(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(alice)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(bob)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(chad)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(dan)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(elvis)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(greg)));

        whiteListedAddresses.push(keccak256(abi.encodePacked(address(liquidityPoolInstance))));

        whiteListedAddresses.push(keccak256(abi.encodePacked(owner)));
        //Needed a whitelisted address that hasn't been registered as a node operator
        whiteListedAddresses.push(keccak256(abi.encodePacked(shonee)));

        root = merkle.getRoot(whiteListedAddresses);

        vm.prank(alice);
        stakingManagerInstance.updateMerkleRoot(root);
    }

    function getWhitelistMerkleProof(uint256 index) internal returns (bytes32[] memory) {
        return merkle.getProof(whiteListedAddresses, index);
    }

    function _initializeMembershipTiers() internal {
        uint40 requiredPointsForTier = 0;
        vm.startPrank(alice);
        for (uint256 i = 0; i < 5; i++) {
            requiredPointsForTier += uint40(28 * 24 * i);
            uint24 weight = uint24(i + 1);
            membershipManagerInstance.addNewTier(requiredPointsForTier, weight);
        }
    }

    function _initializePeople() internal {
        for (uint256 i = 1000; i < 1000 + 36; i++) {
            address actor = vm.addr(i);
            actors.push(actor);
            whitelistIndices.push(whiteListedAddresses.length);
            whiteListedAddresses.push(keccak256(abi.encodePacked(actor)));
            vm.startPrank(actor);
            regulationsManagerInstance.confirmEligibility(termsAndConditionsHash);
            vm.stopPrank();
        }

        vm.startPrank(alice);
        root = merkle.getRoot(whiteListedAddresses);
        stakingManagerInstance.updateMerkleRoot(root);
        vm.stopPrank();
    }

    function _setUpNodeOperatorWhitelist() internal {
        nodeOperatorManagerInstance.addToWhitelist(0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931);
        nodeOperatorManagerInstance.addToWhitelist(0x9154a74AAfF2F586FB0a884AeAb7A64521c64bCf);
        nodeOperatorManagerInstance.addToWhitelist(0xCDca97f61d8EE53878cf602FF6BC2f260f10240B);
        nodeOperatorManagerInstance.addToWhitelist(alice);
        nodeOperatorManagerInstance.addToWhitelist(bob);
        nodeOperatorManagerInstance.addToWhitelist(chad);
        nodeOperatorManagerInstance.addToWhitelist(dan);
        nodeOperatorManagerInstance.addToWhitelist(elvis);
        nodeOperatorManagerInstance.addToWhitelist(greg);
        nodeOperatorManagerInstance.addToWhitelist(address(liquidityPoolInstance));
        nodeOperatorManagerInstance.addToWhitelist(owner);
        nodeOperatorManagerInstance.addToWhitelist(henry);
    }

    function _merkleSetupMigration() internal {
        merkleMigration = new Merkle();
        dataForVerification.push(
            keccak256(
                abi.encodePacked(alice, uint256(0), uint256(10), uint256(0), uint256(0), uint256(0), uint256(400))
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(
                    0xCd5EBC2dD4Cb3dc52ac66CEEcc72c838B40A5931,
                    uint256(0.2 ether),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(0),
                    uint256(652_000_000_000)
                )
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(chad, uint256(0), uint256(10), uint256(0), uint256(50), uint256(0), uint256(9464))
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(bob, uint256(0.1 ether), uint256(0), uint256(0), uint256(0), uint256(0), uint256(400))
            )
        );
        dataForVerification.push(
            keccak256(
                abi.encodePacked(dan, uint256(0.1 ether), uint256(0), uint256(0), uint256(0), uint256(0), uint256(800))
            )
        );
        rootMigration = merkleMigration.getRoot(dataForVerification);
        requiredEapPointsPerEapDeposit.push(0);
        requiredEapPointsPerEapDeposit.push(0); // we want all EAP users to be at least Silver
        requiredEapPointsPerEapDeposit.push(100);
        requiredEapPointsPerEapDeposit.push(400);
        vm.stopPrank();

        vm.prank(alice);
        membershipNftInstance.setUpForEap(rootMigration, requiredEapPointsPerEapDeposit);
    }

    function _merkleSetupMigration2() internal {
        merkleMigration2 = new Merkle();
        dataForVerification2.push(
            keccak256(
                abi.encodePacked(
                    alice,
                    uint256(1 ether),
                    uint256(103680),
                    uint32(16970393 - 10) // 10 blocks before the last gold
                )
            )
        );
        dataForVerification2.push(keccak256(abi.encodePacked(bob, uint256(2 ether), uint256(141738), uint32(0))));
        dataForVerification2.push(keccak256(abi.encodePacked(chad, uint256(2 ether), uint256(139294), uint32(0))));
        dataForVerification2.push(keccak256(abi.encodePacked(dan, uint256(1 ether), uint256(96768), uint32(0))));

        rootMigration2 = merkleMigration2.getRoot(dataForVerification2);
    }

    function _upgradeMembershipManagerFromV0ToV1() internal {
        assertEq(membershipManagerInstance.getImplementation(), address(membershipManagerImplementation));
        membershipManagerV1Implementation = new MembershipManager();
        vm.startPrank(owner);
        membershipManagerInstance.upgradeTo(address(membershipManagerV1Implementation));
        membershipManagerV1Instance = MembershipManager(payable(membershipManagerProxy));
        assertEq(membershipManagerV1Instance.getImplementation(), address(membershipManagerV1Implementation));

        membershipManagerV1Instance.initializePhase2();
        vm.stopPrank();
    }

    function _getDepositRoot() internal returns (bytes32) {
        bytes32 onchainDepositRoot = depositContractEth2.get_deposit_root();
        return onchainDepositRoot;
    }

    function _transferTo(address _recipient, uint256 _amount) internal {
        vm.deal(owner, address(owner).balance + _amount);
        vm.prank(owner);
        (bool sent,) = payable(_recipient).call{value: _amount}("");
        assertEq(sent, true);
    }

    function _moveClock(int256 numSlots) internal {
        assertEq(numSlots > 0, true);
        vm.warp(block.timestamp + uint256(numSlots * 12 seconds));
        vm.roll(block.number + uint256(numSlots));
    }
}
