# Tinlake Contracts
Tinlake is a set of smart contracts that mints an ERC20 token for each unit of value of a group of NFTs it holds in escrow. 

This is a very rough prototype and is not ready for production use.

## Deploy

### Testnet
The easiest way to run these scripts is with `dapp testnet`. Use this command to start a geth devserver.

### Pre-deploy:

- `export ETH_FROM=DEPLOYMENT_ACCOUNT`
- `export ETH_PASSWORD=ACCOUNT_PASSWORD_FILE_PATH`
- `export ETH_KEYSTORE=KEYSTORE_PATH`
- `export ETH_RPC_URL=TESTNET_RPC_NODE_URL`

You can use `. bin/setup-env` to help you set up these variables.

### Deployment with Maker testchain-dss-deployment-scripts
To deploy Tinlake with Maker follow these steps:

1) Deploy Maker with `step-4` described in github.com/makerdao/testchain-dss-deployment-scripts
2) export MCD_ADDRESS_FILE='... path to testchain-dss-deployment-scripts/out/addresses.json...'
3) Run `./bin/deploy-all-maker`
