### Forking Mainnet with Foundry:

→ Using the ‘fork’ commands in foundry we can make the process of fork testing easier by just running tests as we usually do.

## Set Up:

1. We need a variable in the tests to store the fork ID for every fork we create.

```solidity
uint256 mainnetFork;
uint256 goerliFork;
```

1. In the setup function for the tests, we can instantiate the forks like this:

```solidity
mainnetFork = vm.createFork(MAINNET_RPC_URL)
```

where the mainnet rpc url could either be a value stored in the tests or fetched from the env file like this:

```solidity
mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
```

1. Once a fork has been created, we need to fetch the contract instances which we do in the mainnetSetUp function. We fetch all the mainnet contract addresses from the address provider

## Useful Commands:

1. createFork(RPC_URL)
    1. As long as we have the RPC_URL of the network we want to fork, we can create a local chain with the state from the forked network
2. selectFork(mainnetFork)
    1. When we want to test certain functionality, we need to select the fork we would like to use as the current state 
3. activeFork()
    1. Returns the ID of the currently active fork

As long as we have an active fork we can simply run our tests as we usually do but without the fork-url section:

We can roll back to a specific blocknumber if we want to test what happened previously. It is easily seen in the test_EAPRoll where we call vm.rollFork(blocknumber). This allows us to go back to whenever we want.

```solidity
forge test -vvvvv
```

## Creating a Test:

To set up a test it is very similar to the normal way of doing it. Except for a few key features:

1. Make sure their is an active fork
2. Remember all data is being pulled from the forked network
3. Make sure the account performing transactions has ETH (use vm.deal() for this)
    1. Although this is a standard even for normal unit tests