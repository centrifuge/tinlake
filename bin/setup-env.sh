#!/usr/bin/env bash
[[ "$_" != "$0" ]] || { echo >&2 "Use this script by sourcing it \`. $0\` instead"; exit 1; }

TESTNET_PORT=${TESTNET_PORT:-8545}
TESTNET_HOST=${TESTNET_HOST:-localhost}
TESTNET_URL="http://$TESTNET_HOST:$TESTNET_PORT"

echo "Using RPC URL $TESTNET_URL. Change by setting TESTNET_PORT and TESTNET_HOST"

# See if dapp testnet or parity dev chain is running

if [[ "$KEYSTORE_PATH" ]]; then
  true # If KEYSTORE_PATH is set don't look for running ethereum clients
elif { pgrep -a geth && test -d "$HOME/.dapp/testnet/$TESTNET_PORT"; }; then
  KEYSTORE_PATH="$HOME/.dapp/testnet/$TESTNET_PORT/keystore"
  echo Found geth process
elif { pgrep -a parity && test -d "$HOME/.local/share/io.parity.ethereum/keys/DevelopmentChain"; }; then
  KEYSTORE_PATH="$HOME/.local/share/io.parity.ethereum/keys/DevelopmentChain"
  echo Found parity process
else
  echo No ethereum client found, run \'dapp testnet\' and re-run setup script again or set KEYSTORE_PATH.
  return 1
fi

# Set dapptools environment variables
export ETH_PASSWORD="${ETH_PASSWORD:-/dev/null}"
export ETH_KEYSTORE="${ETH_KEYSTORE:-$KEYSTORE_PATH}"
export ETH_RPC_URL="${ETH_RPC_URL:-$TESTNET_URL}"
export ETH_GAS=7000000

export ETH_FROM="${ETH_FROM:-$(seth ls | head -n1 | awk '{print $1}')}"

# For dai.js tests
if command -v sethret > /dev/null 2>&1; then
  find_keyfile() {
    local address
    address="$(tr '[:upper:]' '[:lower:]' <<<"${2#0x}")"
    while IFS= read -r -d '' file; do
      if [[ "$(jq -r .address "$file")" == "$address" ]]; then
        echo "$file"
        break
      fi
    done < <(find "$1" -type f -print0)
  }
  PRIVATE_KEY="$(sethret "$(find_keyfile "$ETH_KEYSTORE" "$ETH_FROM")" "$(cat "$ETH_PASSWORD")")"
  export PRIVATE_KEY
fi
export JSON_RPC="$ETH_RPC_URL"

echo "=== DAPPTOOLS VARIABLES ==="
env | grep ETH_
