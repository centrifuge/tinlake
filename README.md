# Tinlake Contracts
Tinlake is a set of smart contracts that mints an ERC20 token for each unit of value of a group of NFTs it holds in escrow. 

This is a very rough prototype and is not ready for production use.



## Install Dependencies
```bash 
dapp update
```

## Run Tests
```bash
dapp test
```



## Deploy

### Local Deployment

#### Start local Testnet
The easiest way to run these scripts is with `dapp testnet`. Use this command to start a geth devserver.

```bash
dapp testnet --accounts=2
```


#### Local Deploy
```bash
./bin/deploy-all-local
```
The script will setup all needed enviroment variables for a local deployment. Afterwards the backer deploy script is started.  The deployed contract addresses can be 
found in the `deployments` folder. 

#### Testing against a local node
For a local test deployment by default the address `0xe467AEf2203b64760e28D727901067f4745Ea8b8` is set as an admin and
is provided with test ETH and a dummy currency for testing. In addition the address `0xF6fa8a3F3199cDd85749Ec749Fb8F9C2551F9928` can be used as a borrower for testing.
The provided private keys of the two addresses can be used for ui testing with Metamask. 


### Custom Deploy
For deploying to a testnet, mainnet or a customized local deployment the following enviroment variables need to be set.


#### SETH

| Variable | Status |Desc| 
| -------- | -------- |-------- | 
| ETH_RPC_URL     | required     | URL to an Ethereum node or Infura. |
| ETH_FROM |required | Address which signs the transactions for deployment |
| ETH_KEYSTORE | optional | Path to keystore directory of the ETH_FROM address. If the ETH_FROM is from a ledger no keystore dir is needed |
| ETH_PASSWORD | optional | Path to password file. If the ETH_FROM is from a ledger no password file is needed |




#### Tinlake

| Variable | Status |Desc | 
| -------- | -------- | -------- | 
| GOD_ADDR     | required     | address has admin rights on all contracts|
| BACKER_ADDR |required |  second address for Tinlake which provides the liquidity. | 
| CURRENCY |required | ERC20 contract which should be used as a currency for the deployment. On Mainnet this could be the DAI-Stablecoin contract address. (For testnet see Currency section)|
|BACKER_ETH_FROM | optional |  if BACKER_ETH_FROM is set it will `approve` Currency and CVT token for Tinlake|
|BACKER_ETH_KEYSTORE |optional |if BACKER_ETH_FROM is set a keystore directory needs to be provided |
|BACKER_ETH_PASSWORD | optional|  if BACKER_ETH_KEYSTORE is set a password file needs to be provided | 




#### Currency
If you want to deploy a mock NFT and currency NFT contract, you can run `./bin/deploy-mocks` which will deploy them. If you want to deploy Tinlake with an existing ERC20 token, you can set the environment variable `CURRENCY` to the address you want to configure Tinlake with.

#### Deployment with Backer
Deploying Tinlake with the backer funder module will allow you to specify an address from which the $CURRENCY will be taken and the CVT deposited. Set the variable $BACKER_ADDR to set the address used.

If you also supply BACKER_ETH_FROM, BACKER_ETH_PASSWORD and BACKER_ETH_KEYSTORE, it will automatically approve both currency and CVT transfers for the address to the lender.

```bash
./bin/deploy-all-backer  
```


### Deployment with Maker testchain-dss-deployment-scripts
To deploy Tinlake with Maker follow these steps:

1) Deploy Maker with `step-4` described in github.com/makerdao/testchain-dss-deployment-scripts
2) export MCD_ADDRESS_FILE='... path to testchain-dss-deployment-scripts/out/addresses.json...'
3) Run Maker Tinlake deploy script

```bash
./bin/deploy-all-maker
```