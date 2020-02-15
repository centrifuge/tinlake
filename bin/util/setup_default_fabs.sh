#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}

source ./bin/util/util.sh

FABS_FILE=$1
[ -z "$1" ] && FABS_FILE="./../deployments/fabs_$(seth chain).json"

CONFIG_FILE=$2
[ -z "$2" ] && CONFIG_FILE="./bin/config_$(seth chain).json"

loadValuesFromFile $FABS_FILE

addValuesToFile $CONFIG_FILE <<EOF
{
    "TITLE_FAB"             :  "$TITLE_FAB",
    "SHELF_FAB"             :  "$SHELF_FAB",
    "PILE_FAB"              :  "$PILE_FAB",
    "COLLECTOR_FAB"         :  "$COLLECTOR_FAB",
    "THRESHOLD_FAB"         :  "$THRESHOLD_FAB",
    "PRICEPOOL_FAB"         :  "$PRICEPOOL_FAB",
    "DISTRIBUTOR_FAB"       :  "$DISTRIBUTOR_FAB",
    "TRANCHE_FAB"           :  "$TRANCHE_FAB",
    "ASSESSOR_FAB"          :  "$ASSESSOR_DEFAULT_FAB",
    "CEILING_FAB"           :  "$CEILING_PRINICIPAL_FAB",
    "OPERATOR_FAB"          :  "$OPERATOR_WHITELIST_FAB"
}
EOF

message added fabs to config file

message Config File Path: $(realpath $CONFIG_FILE)

cat $CONFIG_FILE

