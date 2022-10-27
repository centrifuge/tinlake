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

For deploying the Tinlake contracts to mainnet or a testnet, view our deploy scripts in [Tinlake Deploy](https://github.com/centrifuge/tinlake-deploy).

## Community

Join our public Discord: [Centrifuge Discord](https://centrifuge.io/discord/).
