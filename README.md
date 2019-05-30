# Tinlake Contracts
## Deploy

### Pre-deploy:

- `export ETH_FROM=DEPLOYMENT_ACCOUNT`
- `export ETH_PASSWORD=ACCOUNT_PASSWORD_FILE_PATH`
- `export ETH_KEYSTORE=KEYSTORE_PATH`
- `export ETH_RPC_URL=TESTNET_RPC_NODE_URL`

You can use `. bin/setup-env.sh` to help you set up these variables.


## TODOs
Features:
* Add method to Maker adapter that triggers lightswitch if Gem was reduced by MKR 
* Aggregate interest by bucket and add total debt number [Lucas]
* LightSwitch should disable other contract methods, build Switchable into contracts
* Interest Chi manipulation contract needs to limit accumulation by day  
* Extract: Contract to remove an asset that is overdue
* Siphon should allow to take DAI out of the Bank

Refactor/Cleanup/Scaling:
* Go through code and add DS-Note and add note to all auth calls
* Go through code and add LightSwitch
* Go through code and add events
* Go through contract and replace unsafe math with safe math
* Go through each file and add headers with license and short description

Other:
* https://github.com/makerdao/dss/blob/master/src/lib.sol#L16 and https://github.com/dapphub/ds-note/blob/master/src/note.sol diverge. Find out which version to use
