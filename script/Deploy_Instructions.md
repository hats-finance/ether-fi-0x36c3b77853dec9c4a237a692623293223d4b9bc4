# EtherFi Contract Suite Deploy Instructions

# Step1:
## Deploy EtherFi Suite
 
Deploy the EtherFi contract suite.

This consists of the Node Operator Manager, Auction Manager, Staking Manager, EtherFi Nodes Manager, Protocol Revenue Manager, EtherFi Node and Treasury contracts. The deploy srcipt will set all dependencies automatically.


# Step 2
## Set Merkle Root

Once all contracts have been deployed and dependencies set up, generate a merkle root and set in using the updateMerkleRoot function on the NodeOperator contract. This will allow for whitelist bidding in the Auction.

