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

### Auto Generate Config File 
For a local deployment a config file can be auto generated.

1. Run in a seperated terminal
```bash
dapp testnet

```

2. Generate Config File
```bash
./bin/test/setup_local_config.sh 

```

## Deploy Contracts
After the config file is defined. Run the follow script

```bash
./bin/deploy.sh
```