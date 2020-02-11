# Tinlake Deployment
A Tinlake Deployment happens with bash scripts and seth.

## Deploy Config File
A config file needs to be defined.
### Required Parameters
```json
{
  "ETH_RPC_URL": "<<RPC URL>>",
  "ETH_FROM": "<<ADDRESS>>",
  "TINLAKE_CURRENCY": "<<ADDRESS>>"
}
```

### Optional Parameters
```json
{
  "ETH_GAS": "<<NUMBER>>",
  "ETH_GAS_PRICE": "<<NUMBER>>",
  "ETH_KEYSTORE": "<<DIR PATH>>",
  "ETH_PASSWORD": "<<FILE PATH>>",
}
```
The config file can contain addresses for Fabs.



## Deploy Contracts
After the config file is defined. Run the follow script

```bash
./bin/deploy.sh
```

## Auto Generate Config File 
For a local deployment a config file can be auto generated.

1. Run in a seperated terminal
```bash
dapp testnet

```

2. Generate Test Config File
```bash
./bin/test/setup_local_config.sh 

```


## Create Fabs
The following command deploys all contract Fabs. (Contract Factories)
```bash
./bin/util/deploy_fabs.sh  <<OPTIONAL: FILE PATH for storing results>>
```
(Fab default path: deployment folder)


### Add Default Fabs to Config File
If the Fabs are added to the config file the deploy script doesn't re-deploy the Fabs
```bash
./bin/util/setup_default_fab.sh  <<OPTIONAL: FABS_FILE PATH>> <<OPTIONAL: CONFIG_FILE PATH>>
```
(Fab default path: deployment folder)