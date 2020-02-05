# Tinlake Deployment
The Tinlake Deployment happens with bash script and the help of seth.


## Deploy Config File
In a first step a config file needs to be defined.

### Required
```json
{
  "ETH_RPC_URL": "<<RPC URL>>",
  "ETH_FROM": "<<ADDRESS>>",
  "TINLAKE_CURRENCY": "<<ADDRESS>>"
}
```

### Optional
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
After a config file is generated run

```bash
./bin/deploy.sh
```