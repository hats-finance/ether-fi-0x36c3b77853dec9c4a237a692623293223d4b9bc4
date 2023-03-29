# EtherFi Contract Suite Deploy Instructions

# Step1:
## Deploy EtherFi Suite
 
Deploy the EtherFi contract suite.

This consists of the Node Operator Manager, Auction Manager, Staking Manager, EtherFi Nodes Manager, Protocol Revenue Manager and Treasury contracts.

Once these contracts are deployed, copy the addresses of the Protocol Revenue Manager and EtherFi Nodes Manager and hardcode them into the etherFi Node contract in their respective functions, namely: 

``` zsh 
etherfiNodesManagerAddress()
```

and 

```zsh
protocolRevenueManagerAddress()
```

# Step 2
## Deploy EtherFi Node

Once the above is done, deploy the EtherFi Node contract and manually call 

``` zsh
registerImplementaionContract(address _etherFiNode)
```

 on the staking manager contract with the address of the deployed node contract as a param. This will then allow the staking manager to create new instances of the EtherFi Node as needed.

# Step 3
## Set Merkle Root

Once all contracts have been deployed and dependencies set up, generate a merkle root and set in using the updateMerkleRoot function on the NodeOperator contract. This will allow for whitelist bidding in the Auction.

