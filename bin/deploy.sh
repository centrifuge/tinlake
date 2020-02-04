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

# deploy root contract
source ./root/deploy.sh