# Tinlake Contracts
Tinlake is a set of smart contracts that mints an ERC20 token for each unit of value of a group of NFTs it holds in escrow. 

This is a very rough prototype and is not ready for production use.

## Deploy

### Pre-deploy:

- `export ETH_FROM=DEPLOYMENT_ACCOUNT`
- `export ETH_PASSWORD=ACCOUNT_PASSWORD_FILE_PATH`
- `export ETH_KEYSTORE=KEYSTORE_PATH`
- `export ETH_RPC_URL=TESTNET_RPC_NODE_URL`

You can use `. bin/setup-env.sh` to help you set up these variables.

### Deployment with Maker testchain-dss-deployment-scripts
To deploy Tinlake with Maker follow these steps:

1) Deploy Maker with `step-4` described in github.com/makerdao/testchain-dss-deployment-scripts
2) export MCD_ADDRESS_FILE='... path to testchain-dss-deployment-scripts/out/addresses.json...'
3) Run `./bin/deploy-all-maker`

## TODOs
Features:
* Test Maker.peek method to Maker adapter that triggers lightswitch if Gem was reduced by MKR 
* LightSwitch should disable other contract methods, build Switchable into contracts
* Extract: Contract to remove an asset that is overdue
* Siphon: should allow to take DAI out of the pile only if debt to lender is 0

Refactor/Cleanup/Scaling:
* Go through code and add DS-Note and add note to all auth calls
* Go through code and add LightSwitch
* Go through code and add events
* Go through contract and replace unsafe math with safe math
* Go through each file and add headers with license and short description

Other:
* https://github.com/makerdao/dss/blob/master/src/lib.sol#L16 and https://github.com/dapphub/ds-note/blob/master/src/note.sol diverge. Find out which version to use
