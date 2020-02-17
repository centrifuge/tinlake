BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
cd $BIN_DIR

source $BIN_DIR/../util/util.sh

# set SETH enviroment variable
source ./local_env.sh

export COLLATERAL_NFT=$(seth send --create ./../../out/Title.bin 'Title(string memory, string memory)' "Test Collateral NFT" ,"TNFT")

message Collateral NFT Address: $COLLATERAL_NFT

DEPLOYMENT_FILE=$BIN_DIR/../../deployments/addresses_$(seth chain).json
touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "COLLATERAL_NFT" :"$COLLATERAL_NFT"
}
EOF