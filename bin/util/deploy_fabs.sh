#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
cd $BIN_DIR

source ./util.sh

CONFIG_FILE=$1
[ -z "$1" ] && CONFIG_FILE="./../config_$(seth chain).json"

loadValuesFromFile $CONFIG_FILE

# check if all required env variables are defined
source ./env-check.sh

success_msg "Correct Config File"


message Create Borrow Fabs

# check or deploy default fabs
[[ -z "$TITLE_FAB" ]] && TITLE_FAB=$(seth send --create ./../../out/TitleFab.bin 'TitleFab()')
[[ -z "$SHELF_FAB" ]] && SHELF_FAB=$(seth send --create ./../../out/ShelfFab.bin 'ShelfFab()')
[[ -z "$PILE_FAB" ]] &&  PILE_FAB=$(seth send --create ./../../out/PileFab.bin 'PileFab()')
[[ -z "$COLLECTOR_FAB" ]] && COLLECTOR_FAB=$(seth send --create ./../../out/CollectorFab.bin 'CollectorFab()')
[[ -z "$THRESHOLD_FAB" ]] && THRESHOLD_FAB=$(seth send --create ./../../out/ThresholdFab.bin 'ThresholdFab()')
[[ -z "$PRICEPOOL_FAB" ]] && PRICEPOOL_FAB=$(seth send --create ./../../out/PricePoolFab.bin 'PricePoolFab()')


[[ -z "$CEILING_PRINICIPAL_FAB" ]] && CEILING_PRINICIPAL_FAB=$(seth send --create ./../../out/PrincipalCeilingFab.bin 'PrincipalCeilingFab()')
[[ -z "$CEILING_CREDITLINE_FAB" ]] && CEILING_CREDITLINE_FAB=$(seth send --create ./../../out/CreditLineCeilingFab.bin 'CreditLineCeilingFab()')

message Create Lender Fabs
# check or deploy default fabs
[[ -z "$OPERATOR_WHITELIST_FAB" ]] && OPERATOR_WHITELIST_FAB=$(seth send --create ./../../out/WhitelistOperatorFab.bin 'WhitelistOperatorFab()')
[[ -z "$OPERATOR_ALLOWANCE_FAB" ]] && OPERATOR_ALLOWANCE_FAB=$(seth send --create ./../../out/AllowanceOperatorFab.bin 'AllowanceOperatorFab()')

[[ -z "$ASSESSOR_DEFAULT_FAB" ]] && ASSESSOR_DEFAULT_FAB=$(seth send --create ./../../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
[[ -z "$ASSESSOR_FI_FAB" ]] && ASSESSOR_FI_FAB=$(seth send --create ./../../out/FullInvestmentAssessorFab.bin 'DefaultAssessorFab()')


[[ -z "$DISTRIBUTOR_FAB" ]] && DISTRIBUTOR_FAB=$(seth send --create ./../../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
[[ -z "$TRANCHE_FAB" ]] && TRANCHE_FAB=$(seth send --create ./../../out/TrancheFab.bin 'TrancheFab()')


FABS_DEPLOYMENT_FILE=$1
[ -z "$1" ] && FABS_DEPLOYMENT_FILE="./../../deployments/fabs_$(seth chain).json"

touch $FABS_DEPLOYMENT_FILE

addValuesToFile $FABS_DEPLOYMENT_FILE <<EOF
{
    "TITLE_FAB"             :  "$TITLE_FAB",
    "SHELF_FAB"             :  "$SHELF_FAB",
    "PILE_FAB"              :  "$PILE_FAB",
    "COLLECTOR_FAB"         :  "$COLLECTOR_FAB",
    "THRESHOLD_FAB"         :  "$THRESHOLD_FAB",
    "PRICEPOOL_FAB"         :  "$PRICEPOOL_FAB",
    "CEILING_PRINICIPAL_FAB":  "$CEILING_PRINICIPAL_FAB",
    "CEILING_CREDITLINE_FAB":  "$CEILING_CREDITLINE_FAB",
    "OPERATOR_WHITELIST_FAB":  "$OPERATOR_WHITELIST_FAB",
    "OPERATOR_ALLOWANCE_FAB":  "$OPERATOR_ALLOWANCE_FAB",
    "ASSESSOR_DEFAULT_FAB"  :  "$ASSESSOR_DEFAULT_FAB",
    "ASSESSOR_FI_FAB"       :  "$ASSESSOR_FI_FAB",
    "DISTRIBUTOR_FAB"       :  "$DISTRIBUTOR_FAB",
    "TRANCHE_FAB"           :  "$TRANCHE_FAB",
    "ASSESSOR_FAB"          :  "$ZERO_ADDRESS",
    "CEILING_FAB"           :  "$ZERO_ADDRESS",
    "SENIOR_TRANCHE_FAB"    :  "$ZERO_ADDRESS",
    "OPERATOR_FAB"          :  "$ZERO_ADDRESS",
    "SENIOR_OPERATOR_FAB"   :  "$ZERO_ADDRESS"
}
EOF

cat $FABS_DEPLOYMENT_FILE

success_msg fabs deployment successful