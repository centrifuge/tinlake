# Tinlake Contracts
Tinlake is a set of smart contracts that mints an ERC20 token for each unit of value of a group of NFTs it holds in escrow. 

This is a very rough prototype and is not ready for production use.

## Deploy

### Testnet
The easiest way to run these scripts is with `dapp testnet`. Use this command to start a geth devserver.


### Pre-deploy:
All deployed addresses are written to `addresses-$(seth chain).json`. To start with a fresh deploy, remove the address file.

- `export ETH_FROM=DEPLOYMENT_ACCOUNT`
- `export ETH_PASSWORD=ACCOUNT_PASSWORD_FILE_PATH`
- `export ETH_KEYSTORE=KEYSTORE_PATH`
- `export ETH_RPC_URL=TESTNET_RPC_NODE_URL`

You can use `. bin/setup-env` to help you set up these variables.

### Currency
If you want to deploy a mock NFT and currency NFT contract, you can run `./bin/deploy-mocks` which will deploy them. If you want to deploy Tinlake with an existing ERC20 token, you can set the environment variable `CURRENCY` to the address you want to configure Tinlake with.

### Deployment with simple backer account
Deploying Tinlake with the backer funder module will allow you to specify an address from which the $CURRENCY will be taken and the CVT deposited. Set the variable $BACKER_ADDR to set the address used.

If you also supply BACKER_ETH_FROM, BACKER_ETH_PASSWORD and BACKER_ETH_KEYSTORE, it will automatically approve both currency and CVT transfers for the address to the lender.

### Deployment with Maker testchain-dss-deployment-scripts
To deploy Tinlake with Maker follow these steps:

1) Deploy Maker with `step-4` described in github.com/makerdao/testchain-dss-deployment-scripts
2) export MCD_ADDRESS_FILE='... path to testchain-dss-deployment-scripts/out/addresses.json...'
3) Run `./bin/deploy-all-maker`
