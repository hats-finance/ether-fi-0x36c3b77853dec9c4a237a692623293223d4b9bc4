-include .env

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

test :; forge test --fork-url https://eth-goerli.g.alchemy.com/v2/0z7pxDff9KkuVkuVY4QxuITXogzKOMS1 --etherscan-api-key 1YTFXGVDUI38JU3RSY7S5AAUPXQXYKR2SR

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

#------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#upgrade commands (GOERLI)
update-goerli-staking-manager :; forge clean && forge script script/upgrades/StakingManagerUpgradeScript.s.sol:StakingManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-auction-manager :; forge clean && forge script script/upgrades/AuctionManagerUpgradeScript.s.sol:AuctionManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-bnft :; forge clean && forge script script/upgrades/BNFTUpgradeScript.s.sol:BNFTUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-tnft :; forge clean && forge script script/upgrades/TNFTUpgradeScript.s.sol:TNFTUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-claim-receiver-pool :; forge clean && forge script script/upgrades/ClaimReceiverPoolUpgradeScript.s.sol:ClaimReceiverPoolUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-eeth :; forge clean && forge script script/upgrades/EETHUpgradeScript.s.sol:EETHUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-etherfi_nodes_manager :; forge clean && forge script script/upgrades/EtherFiNodesManagerUpgradeScript.s.sol:EtherFiNodesManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-liquidity_pool :; forge clean && forge script script/upgrades/LiquidityPoolUpgradeScript.s.sol:LiquidityPoolUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-meeth :; forge clean && forge script script/upgrades/MeETHUpgradeScript.s.sol:MeETHUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-node_operator_manager :; forge clean && forge script script/upgrades/NodeOperatorManagerUpgradeScript.s.sol:NodeOperatorManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-protocol_revenue_manager :; forge clean && forge script script/upgrades/ProtocolRevenueManagerUpgradeScript.s.sol:ProtocolRevenueManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-regulations_manager :; forge clean && forge script script/upgrades/RegulationsManagerUpgradeScript.s.sol:RegulationsManagerUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-goerli-weeth :; forge clean && forge script script/upgrades/WeETHUpgradeScript.s.sol:WeEthUpgrade --rpc-url ${GOERLI_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh


#--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#upgrade commands (MAINNET)
update-staking-manager :; forge clean && forge script script/upgrades/StakingManagerUpgradeScript.s.sol:StakingManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-auction-manager :; forge clean && forge script script/upgrades/AuctionManagerUpgradeScript.s.sol:AuctionManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-bnft :; forge clean && forge script script/upgrades/BNFTUpgradeScript.s.sol:BNFTUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-tnft :; forge clean && forge script script/upgrades/TNFTUpgradeScript.s.sol:TNFTUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-claim-receiver-pool :; forge clean && forge script script/upgrades/ClaimReceiverPoolUpgradeScript.s.sol:ClaimReceiverPoolUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-eeth :; forge clean && forge script script/upgrades/EETHUpgradeScript.s.sol:EETHUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-etherfi_nodes_manager :; forge clean && forge script script/upgrades/EtherFiNodesManagerUpgradeScript.s.sol:EtherFiNodesManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-liquidity_pool :; forge clean && forge script script/upgrades/LiquidityPoolUpgradeScript.s.sol:LiquidityPoolUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-meeth :; forge clean && forge script script/upgrades/MeETHUpgradeScript.s.sol:MeETHUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-node_operator_manager :; forge clean && forge script script/upgrades/NodeOperatorManagerUpgradeScript.s.sol:NodeOperatorManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-protocol_revenue_manager :; forge clean && forge script script/upgrades/ProtocolRevenueManagerUpgradeScript.s.sol:ProtocolRevenueManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-regulations_manager :; forge clean && forge script script/upgrades/RegulationsManagerUpgradeScript.s.sol:RegulationsManagerUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh

update-weeth :; forge clean && forge script script/upgrades/WeETHUpgradeScript.s.sol:WeEthUpgrade --rpc-url ${MAINNET_RPC_URL} --broadcast --verify -vvvv --slow && bash script/extractABI.sh



extract-abi :; bash script/extractABI.sh