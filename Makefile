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

test :; forge test

snapshot :; forge snapshot

slither :; slither ./src 

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

# use the "@" to hide the command from your shell 
deploy-goerli-suite :; @forge script script/DeployEtherFISuite.s.sol:DeployScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv

deploy-goerli-lp :; @forge script script/DeployLiquidityPool.s.sol:DeployLiquidityPoolScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv

deploy-goerli-depositPool :; @forge script script/DeployDepositPool.s.sol:DeployDepositPoolScript --rpc-url ${GOERLI_RPC_URL} --broadcast --verify  -vvvv

extract-abi :; bash script/extractABI.sh