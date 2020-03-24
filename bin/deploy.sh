#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}

source $BIN_DIR/util/util.sh
message Start Tinlake deployment

cd $BIN_DIR
CONFIG_FILE=$1
[ -z "$1" ] && CONFIG_FILE="./config_$(seth chain).json"

loadValuesFromFile $CONFIG_FILE

# check if all required env variables are defined
source $BIN_DIR/util/env-check.sh

success_msg "Correct Config File"

# build contracts if needed
build_contracts "./.."

# create deployment folder
mkdir -p $BIN_DIR/../deployments

# deploy root contract
source ./root/deploy.sh

# deploy lender contracts
source ./lender/deploy.sh

# deploy borrower contracts
source ./borrower/deploy.sh

# finalize deployment
message Finalize Deployment

[[ -z "$GOVERNANCE" ]] && GOVERNANCE="0x$ETH_FROM"

seth send $ROOT_CONTRACT 'prepare(address,address,address)' $LENDER_DEPLOYER $BORROWER_DEPLOYER $GOVERNANCE
seth send $ROOT_CONTRACT 'deploy()'

success_msg "Tinlake Deployment Finished"
success_msg "Deployment File: $(realpath $DEPLOYMENT_FILE)"

#touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "GOVERNANCE" : "$GOVERNANCE"
}
EOF

cat $DEPLOYMENT_FILE

success_msg DONE
