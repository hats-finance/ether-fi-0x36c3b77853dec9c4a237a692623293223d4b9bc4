# EtherFi Contract Phase One Deploy Instructions

# Step 1:
## Setup Environment

Once you have the environment on VS code, you will need to run the following three commands to get everything working.
* curl -L https://foundry.paradigm.xyz | bash
* foundryup
* git submodule update --init --recursive

# Step 2:
## Deploy EtherFi Suite
 
Deploy the EtherFi phase one suite.

This consists of the Node Operator Manager, Auction Manager, Staking Manager, EtherFi Nodes Manager, Protocol Revenue Manager, EtherFi Node, Treasury, TNFT, BNFT and Score Manager contracts. The deploy srcipt will set all dependencies automatically.

There are a few important variable to set before running the deploy command.

If you currently do not have a .env file, and only a .example.env, perform the following:
1. Copy the .example.env file and create a new file with the same contents called .env (this name will hide it from public sources)
2. The file will consist of the following:

    * GOERLI_RPC_URL=
    * PRIVATE_KEY=
    * ETHERSCAN_API_KEY=

3. Please fill in the data accordingly. You can find a GOERLI_RPC_URL or MAINNET_RPC_URL in the case of mainnet deployment, on Alchemy. The private key used here will be the multisig wallet you wish to use. And lastly you can retreive a ETHERSCAN_API_KEY from etherscan if you sign up.

4. Once your environment is set up, run
    source .env

5. Lastly, run the following command to deploy
    forge script script/DeployPhaseOne.s.sol:DeployPhaseOne --rpc-url $GOERLI_RPC_URL --broadcast --slow --verify -vvvv

If you are deploying to mainnet, change $GOERLI_RPC_URL to $MAINNET_RPC_URL


# Step 3
## Set Merkle Root

Once all contracts have been deployed and dependencies set up, we will need to update the merkle roots. 

1. Generate the merkle tree for the Node Operators and call the updateMerkleRoot function in the Node Operator Manager to set the root.
2. Gnerate the merkle tree for stakers who are whitelisted and call the updateMerkleRoot function in the Staking Manager to set the root.

