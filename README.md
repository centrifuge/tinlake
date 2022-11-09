# Tinlake Contracts

Open source implementation of Tinlake in Solidity. This repository contains the core contracts of Tinlake.

Tinlake is a set of smart contracts that allows companies and individuals to use tokenized non-fungible real-world assets as collateral to obtain liquidity.

For learning more about how Tinlake works, you can visit the [Tinlake documentation](https://developer.centrifuge.io/tinlake/overview/introduction/).

## Getting started

Tinlake uses [foundry](https://github.com/foundry-rs/foundry) for development. Please install the [foundry client](https://getfoundry.sh/). Then, run the following command to install the dependencies:

```bash
forge update
```

## Testing

The tests for Tinlake are written in Solidity

### Run all tests

```bash
forge test
```

### Run specific tests

A regular expression can be used to only run specific tests.

```bash
forge test -m <REGEX>
forge test -m testName
forge test -m ':ContractName\.'
```

## Deployment

To deploy Tinlake, you need to set up a `.env` file with the deployment parameters. A sample file can be found in `.env.example`.

To confirm that the `.env` file is set up correctly, run:
```bash
./bin/env-check.sh
```

Once you've double checked all the environment variables, the deployment can be started:
```bash
forge script script/deploy.s.sol:TinlakeDeployScript --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
```

## Community

Join our public Discord: [Centrifuge Discord](https://centrifuge.io/discord/).
