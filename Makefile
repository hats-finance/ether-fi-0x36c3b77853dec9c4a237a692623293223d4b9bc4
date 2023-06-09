-include .env
export

.PHONY: all test clean deploy-anvil extract-abi

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test --fork-url ${RPC_API_KEY} --etherscan-api-key ${ETHERSCAN_API_KEY}

snapshot :; forge snapshot

slither :; slither ./src 

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol
#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# use the "@" to hide the command from your shell 
deploy-goerli-suite :; @forge script script/deploys/DeployEtherFISuite.s.sol:DeployEtherFiSuiteScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow

deploy-goerli-early-reward-pool :; @forge script script/deploys/DeployEarlyAdopterPool.s.sol:DeployEarlyAdopterPoolScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow

deploy-phase-1:; forge clean && forge script script/deploys/DeployPhaseOne.s.sol:DeployPhaseOne --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow && bash script/extractABI.sh

deploy-test-deposit-contract:; forge clean && forge script script/deploys/goerli/DeployTestDepositContract.s.sol:DeployTestDepositContractScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow && bash script/extractABI.sh

deploy-goerli-phase-1.5:; forge clean && forge script script/deploys/goerli/DeployPhaseOnePointFive.s.sol:DeployPhaseOnePointFiveScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow && bash script/extractABI.sh

deploy-mainnet-phase-1.5:; forge clean && forge script script/deploys/mainnet/DeployPhaseOnePointFive.s.sol:DeployPhaseOnePointFiveScript --rpc-url ${MAINNET_RPC_URL} --broadcast --verify  -vvvv --slow && bash script/extractABI.sh

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#upgrade commands (GOERLI)
upgrade-goerli-staking-manager :; forge clean && forge script script/upgrades/goerli/GoerliStakingManagerUpgradeScript.s.sol:StakingManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-auction-manager :; forge clean && forge script script/upgrades/goerli/GoerliAuctionManagerUpgradeScript.s.sol:AuctionManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-bnft :; forge clean && forge script script/upgrades/goerli/GoerliBNFTUpgradeScript.s.sol:BNFTUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-tnft :; forge clean && forge script script/upgrades/goerli/GoerliTNFTUpgradeScript.s.sol:TNFTUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-eeth :; forge clean && forge script script/upgrades/goerli/GoerliEETHUpgradeScript.s.sol:EETHUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-etherfi_nodes_manager :; forge clean && forge script script/upgrades/goerli/GoerliEtherFiNodesManagerUpgradeScript.s.sol:EtherFiNodesManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-liquidity_pool :; forge clean && forge script script/upgrades/goerli/GoerliLiquidityPoolUpgradeScript.s.sol:LiquidityPoolUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-membership-manager :; forge clean && forge script script/upgrades/goerli/GoerliMembershipManagerUpgradeScript.s.sol:MembershipManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-node_operator_manager :; forge clean && forge script script/upgrades/goerli/GoerliNodeOperatorManagerUpgradeScript.s.sol:NodeOperatorManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-protocol_revenue_manager :; forge clean && forge script script/upgrades/goerli/GoerliProtocolRevenueManagerUpgradeScript.s.sol:ProtocolRevenueManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-regulations_manager :; forge clean && forge script script/upgrades/goerli/GoerliRegulationsManagerUpgradeScript.s.sol:RegulationsManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-goerli-weeth :; forge clean && forge script script/upgrades/goerli/GoerliWeETHUpgradeScript.s.sol:WeEthUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh


#--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#upgrade commands (MAINNET)
upgrade-staking-manager :; forge clean && forge script script/upgrades/mainnet/MainnetStakingManagerUpgradeScript.s.sol:StakingManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-auction-manager :; forge clean && forge script script/upgrades/mainnet/MainnetAuctionManagerUpgradeScript.s.sol:AuctionManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-bnft :; forge clean && forge script script/upgrades/mainnet/MainnetBNFTUpgradeScript.s.sol:BNFTUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-tnft :; forge clean && forge script script/upgrades/mainnet/MainnetTNFTUpgradeScript.s.sol:TNFTUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-eeth :; forge clean && forge script script/upgrades/mainnet/MainnetEETHUpgradeScript.s.sol:EETHUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-etherfi_nodes_manager :; forge clean && forge script script/upgrades/mainnet/MainnetEtherFiNodesManagerUpgradeScript.s.sol:EtherFiNodesManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-liquidity_pool :; forge clean && forge script script/upgrades/mainnet/MainnetLiquidityPoolUpgradeScript.s.sol:LiquidityPoolUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-membership-manager :; forge clean && forge script script/upgrades/mainnet/MainnetMembershipManagerUpgradeScript.s.sol:MembershipManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-node_operator_manager :; forge clean && forge script script/upgrades/mainnet/MainnetNodeOperatorManagerUpgradeScript.s.sol:NodeOperatorManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-protocol_revenue_manager :; forge clean && forge script script/upgrades/mainnet/MainnetProtocolRevenueManagerUpgradeScript.s.sol:ProtocolRevenueManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-regulations_manager :; forge clean && forge script script/upgrades/mainnet/MainnetRegulationsManagerUpgradeScript.s.sol:RegulationsManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

upgrade-weeth :; forge clean && forge script script/upgrades/mainnet/MainnetWeETHUpgradeScript.s.sol:WeEthUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh



deploy-patch-2:; forge clean && forge script script/DeployPatch2.s.sol:DeployPatchV3 --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv --slow

extract-abi :; bash script/extractABI.sh
