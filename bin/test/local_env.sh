# Define ENV
GETH_DIR=$HOME/.dapp/testnet/8545

# Default Test Config
export ETH_RPC_URL=http://127.0.0.1:8545
export ETH_KEYSTORE=$GETH_DIR/keystore
touch $GETH_DIR/.empty-password
export ETH_PASSWORD=$GETH_DIR/.empty-password
export ETH_FROM=$(cat $GETH_DIR/keystore/* | jq -r '.address' | head -n 1)

export ETH_GAS=${ETH_GAS:-"7000000"}