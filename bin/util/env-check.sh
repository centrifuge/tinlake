
BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util.sh

message Enviroment Variables

if [[ -z "$ETH_RPC_URL" ]]; then
    error_exit "ETH_RPC_URL is not defined"
fi
echo "ETH_RPC_URL=$ETH_RPC_URL"

if [[ -z "$ETH_FROM" ]]; then
    error_exit "ETH_FROM is not defined"
fi
echo "ETH_FROM=$ETH_FROM"

if [[ -z "$ETH_GAS" ]]; then
    warning_msg "ETH_GAS is not defined"
fi
echo "ETH_GAS=$ETH_GAS"
if [[ -z "$ETH_GAS_PRICE" ]]; then
    warning_msg "ETH_GAS_PRICE is not defined"
fi
echo "ETH_GAS_PRICE=$ETH_GAS_PRICE"

message Tinlake Variables
if [[ -z "$TINLAKE_CURRENCY" ]]; then
    error_exit "TINLAKE_CURRENCY is not defined"
fi
echo "TINLAKE_CURRENCY=$TINLAKE_CURRENCY"