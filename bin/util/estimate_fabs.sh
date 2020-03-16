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

message Estimate Gas

# check or deploy default fabs

SUM=0

TITLE_FAB=$(seth estimate --create ./../../out/TitleFab.bin 'TitleFab()')
echo "TITLE_FAB Gas: $TITLE_FAB"
SUM=$((SUM + TITLE_FAB))
SHELF_FAB=$(seth estimate --create ./../../out/ShelfFab.bin 'ShelfFab()')
echo "SHELF_FAB Gas: $SHELF_FAB"
SUM=$((SUM + SHELF_FAB))
PILE_FAB=$(seth estimate --create ./../../out/PileFab.bin 'PileFab()')
echo "PILE_FAB Gas: $PILE_FAB"
SUM=$((SUM + PILE_FAB))
COLLECTOR_FAB=$(seth estimate --create ./../../out/CollectorFab.bin 'CollectorFab()')
echo "COLLECTOR_FAB Gas: $COLLECTOR_FAB"
SUM=$((SUM + COLLECTOR_FAB))
THRESHOLD_FAB=$(seth estimate --create ./../../out/ThresholdFab.bin 'ThresholdFab()')
echo "THRESHOLD_FAB Gas: $THRESHOLD_FAB"
SUM=$((SUM + THRESHOLD_FAB))
PRICEPOOL_FAB=$(seth estimate --create ./../../out/PricePoolFab.bin 'PricePoolFab()')
echo "PRICEPOOL_FAB Gas: $PRICEPOOL_FAB"
SUM=$((SUM + PRICEPOOL_FAB))
CEILING_PRINICIPAL_FAB=$(seth estimate --create ./../../out/PrincipalCeilingFab.bin 'PrincipalCeilingFab()')
echo "CEILING_PRINICIPAL_FAB Gas: $CEILING_PRINICIPAL_FAB"
SUM=$((SUM + CEILING_PRINICIPAL_FAB))
CEILING_CREDITLINE_FAB=$(seth estimate --create ./../../out/CreditLineCeilingFab.bin 'CreditLineCeilingFab()')
echo "CEILING_CREDITLINE_FAB Gas: $CEILING_CREDITLINE_FAB"
SUM=$((SUM + CEILING_CREDITLINE_FAB))
message Create Lender Fabs
# check or deploy default fabs
OPERATOR_WHITELIST_FAB=$(seth estimate --create ./../../out/WhitelistOperatorFab.bin 'WhitelistOperatorFab()')
echo "OPERATOR_WHITELIST_FAB Gas: $OPERATOR_WHITELIST_FAB"
SUM=$((SUM + OPERATOR_WHITELIST_FAB))
OPERATOR_ALLOWANCE_FAB=$(seth estimate --create ./../../out/AllowanceOperatorFab.bin 'AllowanceOperatorFab()')
echo "OPERATOR_ALLOWANCE_FAB Gas: $OPERATOR_ALLOWANCE_FAB"
SUM=$((SUM + OPERATOR_ALLOWANCE_FAB))
ASSESSOR_DEFAULT_FAB=$(seth estimate --create ./../../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
echo "ASSESSOR_DEFAULT_FAB Gas: $ASSESSOR_DEFAULT_FAB"
SUM=$((SUM + ASSESSOR_DEFAULT_FAB))
ASSESSOR_FI_FAB=$(seth estimate --create ./../../out/FullInvestmentAssessorFab.bin 'DefaultAssessorFab()')
echo "ASSESSOR_FI_FAB Gas: $ASSESSOR_FI_FAB"
SUM=$((SUM + ASSESSOR_FI_FAB))
DISTRIBUTOR_FAB=$(seth estimate --create ./../../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
echo "DISTRIBUTOR_FAB Gas: $DISTRIBUTOR_FAB"
SUM=$((SUM + DISTRIBUTOR_FAB))
TRANCHE_FAB=$(seth estimate --create ./../../out/TrancheFab.bin 'TrancheFab()')
echo "TRANCHE_FAB Gas: $TRANCHE_FAB"
SUM=$((SUM + TRANCHE_FAB))

echo "TOTAL Gas: $SUM"