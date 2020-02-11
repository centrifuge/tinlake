#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util/util.sh

cd $BIN_DIR

message Deploy Borrower

# todo it should be possible to define other path
DEPLOYMENT_FILE="./../deployments/addresses_$(seth chain).json"
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

message Borrower Check or Deploy Fabs

# check or deploy default fabs
[[ -z "$TITLE_FAB" ]] && TITLE_FAB=$(seth send --create ./../out/TitleFab.bin 'TitleFab()')
[[ -z "$SHELF_FAB" ]] && SHELF_FAB=$(seth send --create ./../out/ShelfFab.bin 'ShelfFab()')
[[ -z "$PILE_FAB" ]] && PILE_FAB=$(seth send --create ./../out/PileFab.bin 'PileFab()')
[[ -z "$COLLECTOR_FAB" ]] && COLLECTOR_FAB=$(seth send --create ./../out/CollectorFab.bin 'CollectorFab()')
[[ -z "$THRESHOLD_FAB" ]] && THRESHOLD_FAB=$(seth send --create ./../out/ThresholdFab.bin 'ThresholdFab()')
[[ -z "$PRICEPOOL_FAB" ]] && PRICEPOOL_FAB=$(seth send --create ./../out/PricePoolFab.bin 'PricePoolFab()')
# default is Principal Ceiling Fab
[[ -z "$CEILING_FAB" ]] && CEILING_FAB=$(seth send --create ./../out/PrincipalCeilingFab.bin 'PrincipalCeilingFab()')

success_msg Borrower Fabs ready

TITLE_NAME="Tinlake Loan Token"
TITLE_SYMBOL="TLNT"

export DEPLOYER=$(seth send --create ./../out/BorrowerDeployer.bin 'BorrowerDeployer(address,address,address,address,address,address,address,address,address,string memory,string memory)' $ROOT_CONTRACT $TITLE_FAB $SHELF_FAB $PILE_FAB $CEILING_FAB $COLLECTOR_FAB $THRESHOLD_FAB $PRICEPOOL_FAB $TINLAKE_CURRENCY "$TITLE_NAME" "$TITLE_SYMBOL")


seth send $DEPLOYER 'deployTitle()'
seth send $DEPLOYER 'deployPile()'
seth send $DEPLOYER 'deployCeiling()'
seth send $DEPLOYER 'deployShelf()'
seth send $DEPLOYER 'deployThreshold()'
seth send $DEPLOYER 'deployCollector()'
seth send $DEPLOYER 'deployPricePool()'

seth send $DEPLOYER 'deploy()'

success_msg Borrower Contracts deployed

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "BORROWER_DEPLOYER"       :  "$DEPLOYER",
    "TITLE_FAB"      :  "$TITLE_FAB",
    "SHELF_FAB"      :  "$SHELF_FAB",
    "PILE_FAB"       :  "$PILE_FAB",
    "COLLECTOR_FAB"  :  "$COLLECTOR_FAB",
    "THRESHOLD_FAB"  :  "$THRESHOLD_FAB",
    "PRICEPOOL_FAB"  :  "$PRICEPOOL_FAB",
    "CEILING_FAB"    :  "$CEILING_FAB",
    "TITLE"          :  "0x$(seth call $DEPLOYER 'title()(address)')",
    "PILE"           :  "0x$(seth call $DEPLOYER 'pile()(address)')",
    "SHELF"          :  "0x$(seth call $DEPLOYER 'shelf()(address)')",
    "CEILING"        :  "0x$(seth call $DEPLOYER 'ceiling()(address)')",
    "COLLECTOR"      :  "0x$(seth call $DEPLOYER 'collector()(address)')",
    "THRESHOLD"      :  "0x$(seth call $DEPLOYER 'threshold()(address)')",
    "PRICE_POOL"     :  "0x$(seth call $DEPLOYER 'pricePool()(address)')"
}
EOF