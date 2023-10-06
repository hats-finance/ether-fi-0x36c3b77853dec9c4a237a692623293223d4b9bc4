## Step 1 - Deploy EAP

### Confirm ERC-20 Addresses:
- R_ETH: 0xf533a7110e30eb4f5ec8ae033bc0ccaf07bf1b0f
- WST_ETH: 0x817d236968e7089a93aecfe817ad685cb72e9dd7
- SFRX_ETH: 0xda976f84a98be3e5663023a466948ef6883d577b
- CB_ETH: 0x7660e1ef7279bd0ef2ded5379f1a499540784e8e

### Setup .env for deploy

```
GOERLI_RPC_URL=https://eth-goerli.g.alchemy.com/v2/Gj8oS16rKivma6TYb_xZFiLY-EJJZ0jn
PRIVATE_KEY=36b134b83ac3fb9391e629e9f36c413295aae42840d663fae66f6bfb9b9f7a0a
ETHERSCAN_API_KEY=9BN8Q9Q875QI9VNH3NA14WGTD9D47AY6BH
ERC_20_R_ETH_ADDRESS=0xf533a7110e30eb4f5ec8ae033bc0ccaf07bf1b0f
ERC_20_WST_ETH_ADDRESS=0x817d236968e7089a93aecfe817ad685cb72e9dd7
ERC_20_SFRX_ETH_ADDRESS=0xda976f84a98be3e5663023a466948ef6883d577b
ERC_20_CB_ETH_ADDRESS=0x7660e1ef7279bd0ef2ded5379f1a499540784e8e
```

### Run script

```
make deploy-goerli-early-reward-pool
```

### Success

Update docs in https://www.notion.so/Contract-Addresses-087bd1d374f14cd7a6a3de523602ec6b for relevant contract

Record commit hash used: (66401b00)

Step 2 - 
Deploy Phase 1

Step 3 -
Deploy Phase 1.5

May-19-2023