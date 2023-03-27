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
These two addresses are predetermined using the Create2 opcode upon deployment.

# Step 2
## Deploy EtherFi Node

Once this is done, deploy the EtherFi Node contract and manually call 

``` zsh
registerImplementaionContract(address _etherFiNode)
```

 on the staking manager contract with the address of the deployed node contract as a param. This will then allow the staking manager to create new instances of the EtherFi Node as needed.

