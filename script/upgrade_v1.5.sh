#!/bin/bash

set -e  # Exit immediately if any command fails

targets=(
  upgrade-goerli-staking-manager
  upgrade-goerli-auction-manager
  upgrade-goerli-etherfi-node
  upgrade-goerli-bnft
  upgrade-goerli-tnft
  upgrade-goerli-eeth
  upgrade-goerli-etherfi_nodes_manager
  upgrade-goerli-liquidity-pool
  upgrade-goerli-membership-manager
  upgrade-goerli-membership-nft
  upgrade-goerli-weeth
)

for target in "${targets[@]}"; do
  make "$target"
done

