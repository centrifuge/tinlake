BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
cd $BIN_DIR

source ./../util/util.sh

# set SETH enviroment variable
source ./local_env.sh

export COLLATERAL_NFT=$(seth send --create ./../../out/Title.bin 'Title(string memory, string memory)' "Test Collateral NFT" ,"TNFT")

message Collateral NFT Address: $COLLATERAL_NFT