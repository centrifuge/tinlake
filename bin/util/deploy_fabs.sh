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
echo "TITLE_FAB : $TITLE_FAB"
[[ -z "$SHELF_FAB" ]] && SHELF_FAB=$(seth send --create ./../../out/ShelfFab.bin 'ShelfFab()')
echo "SHELF_FAB : $SHELF_FAB"
[[ -z "$PILE_FAB" ]] &&  PILE_FAB=$(seth send --create ./../../out/PileFab.bin 'PileFab()')
echo "PILE_FAB : $PILE_FAB"
[[ -z "$COLLECTOR_FAB" ]] && COLLECTOR_FAB=$(seth send --create ./../../out/CollectorFab.bin 'CollectorFab()')
echo "COLLECTOR_FAB : $COLLECTOR_FAB"
[[ -z "$THRESHOLD_FAB" ]] && THRESHOLD_FAB=$(seth send --create ./../../out/ThresholdFab.bin 'ThresholdFab()')
echo "THRESHOLD_FAB : $THRESHOLD_FAB"
[[ -z "$PRICEPOOL_FAB" ]] && PRICEPOOL_FAB=$(seth send --create ./../../out/PricePoolFab.bin 'PricePoolFab()')
echo "PRICEPOOL_FAB : $PRICEPOOL_FAB"
[[ -z "$CEILING_PRINICIPAL_FAB" ]] && CEILING_PRINICIPAL_FAB=$(seth send --create ./../../out/PrincipalCeilingFab.bin 'PrincipalCeilingFab()')
echo "CEILING_PRINICIPAL_FAB : $CEILING_PRINICIPAL_FAB"
[[ -z "$CEILING_CREDITLINE_FAB" ]] && CEILING_CREDITLINE_FAB=$(seth send --create ./../../out/CreditLineCeilingFab.bin 'CreditLineCeilingFab()')
echo "CEILING_CREDITLINE_FAB : $CEILING_CREDITLINE_FAB"
message Create Lender Fabs
# check or deploy default fabs
[[ -z "$OPERATOR_WHITELIST_FAB" ]] && OPERATOR_WHITELIST_FAB=$(seth send --create ./../../out/WhitelistOperatorFab.bin 'WhitelistOperatorFab()')
echo "OPERATOR_WHITELIST_FAB : $OPERATOR_WHITELIST_FAB"
[[ -z "$OPERATOR_ALLOWANCE_FAB" ]] && OPERATOR_ALLOWANCE_FAB=$(seth send --create ./../../out/AllowanceOperatorFab.bin 'AllowanceOperatorFab()')
echo "OPERATOR_ALLOWANCE_FAB : $OPERATOR_ALLOWANCE_FAB"
[[ -z "$ASSESSOR_DEFAULT_FAB" ]] && ASSESSOR_DEFAULT_FAB=$(seth send --create ./../../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
echo "ASSESSOR_DEFAULT_FAB : $ASSESSOR_DEFAULT_FAB"
[[ -z "$ASSESSOR_FI_FAB" ]] && ASSESSOR_FI_FAB=$(seth send --create ./../../out/FullInvestmentAssessorFab.bin 'DefaultAssessorFab()')
echo "ASSESSOR_FI_FAB : $ASSESSOR_FI_FAB"
[[ -z "$DISTRIBUTOR_FAB" ]] && DISTRIBUTOR_FAB=$(seth send --create ./../../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
echo "DISTRIBUTOR_FAB : $DISTRIBUTOR_FAB"
[[ -z "$TRANCHE_FAB" ]] && TRANCHE_FAB=$(seth send --create ./../../out/TrancheFab.bin 'TrancheFab()')
echo "TRANCHE_FAB : $TRANCHE_FAB"

FABS_DEPLOYMENT_FILE=$2
[ -z "$2" ] && FABS_DEPLOYMENT_FILE="./../../deployments/fabs_$(seth chain).json"

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