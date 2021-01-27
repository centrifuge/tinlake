# Tinlake Contracts
Open source implementation of Tinlake in Solidity. This repository contains the core contracts of Tinlake.

Tinlake is a set of smart contracts that allows companies and individuals to use tokenized non-fungible real-world assets as collateral to obtain liquidity. 

For learning more about how Tinlake works, you can visit the [Tinlake documentation](https://developer.centrifuge.io/tinlake/overview/introduction/).

## Getting started
Tinlake uses [dapp.tools](https://github.com/dapphub/dapptools) for development. Please install the `dapp` client. Then, run the following command to install the dependencies:

```bash 
dapp update
```

## Testing
The tests for Tinlake are written in Solidity. To set up your environment, you should add these variables:
```bash
export DAPP_SOLC_VERSION=0.5.15
export DAPP_TEST_TIMESTAMP=1234567
```

### Run all tests
```bash
dapp test
```

### Run specific tests
A regular expression can be used to only run specific tests. The regex matches test names, rather than contract names.

```bash
dapp test -m <REGEX>
dapp test -m testName
```

## Deployment
For deploying the Tinlake contracts to mainnet or a testnet, view our deploy scripts in [Tinlake Deploy](https://github.com/centrifuge/tinlake-deploy).

## Community
Join our public Slack channel: [Centrifuge Slack](http://centrifuge.io/slack).
