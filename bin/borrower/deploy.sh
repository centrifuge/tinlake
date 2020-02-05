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
[[ -z "$BORROWER_TITLE_FAB" ]] && BORROWER_TITLE_FAB=$(seth send --create ./../out/TitleFab.bin 'TitleFab()')
[[ -z "$BORROWER_SHELF_FAB" ]] && BORROWER_SHELF_FAB=$(seth send --create ./../out/ShelfFab.bin 'ShelfFab()')
[[ -z "$BORROWER_PILE_FAB" ]] && BORROWER_PILE_FAB=$(seth send --create ./../out/PileFab.bin 'PileFab()')
[[ -z "$BORROWER_COLLECTOR_FAB" ]] && BORROWER_COLLECTOR_FAB=$(seth send --create ./../out/CollectorFab.bin 'CollectorFab()')
[[ -z "$BORROWER_THRESHOLD_FAB" ]] && BORROWER_THRESHOLD_FAB=$(seth send --create ./../out/ThresholdFab.bin 'ThresholdFab()')
[[ -z "$BORROWER_PRICEPOOL_FAB" ]] && BORROWER_PRICEPOOL_FAB=$(seth send --create ./../out/PricePoolFab.bin 'PricePoolFab()')
# default is Principal Ceiling Fab
[[ -z "$BORROWER_CEILING_FAB" ]] && BORROWER_CEILING_FAB=$(seth send --create ./../out/PrincipalCeilingFab.bin 'PrincipalCeilingFab()')

success_msg Borrower Fabs ready

TITLE_NAME="Tinlake Loan Token"
TITLE_SYMBOL="TLNT"

export BORROWER_DEPLOYER=$(seth send --create ./../out/BorrowerDeployer.bin 'BorrowerDeployer(address,address,address,address,address,address,address,address,address,string memory,string memory)' $ROOT_CONTRACT $BORROWER_TITLE_FAB $BORROWER_SHELF_FAB $BORROWER_PILE_FAB $BORROWER_CEILING_FAB $BORROWER_COLLECTOR_FAB $BORROWER_THRESHOLD_FAB $BORROWER_PRICEPOOL_FAB $TINLAKE_CURRENCY "$TITLE_NAME" "$TITLE_SYMBOL")


seth send $BORROWER_DEPLOYER 'deployTitle()'
seth send $BORROWER_DEPLOYER 'deployPile()'
seth send $BORROWER_DEPLOYER 'deployCeiling()'
seth send $BORROWER_DEPLOYER 'deployShelf()'
seth send $BORROWER_DEPLOYER 'deployThreshold()'
seth send $BORROWER_DEPLOYER 'deployCollector()'
seth send $BORROWER_DEPLOYER 'deployPricePool()'

seth send $BORROWER_DEPLOYER 'deploy()'

success_msg Borrower Contracts deployed

touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "BORROWER_DEPLOYER"       :  "$BORROWER_DEPLOYER",
    "BORROWER_TITLE_FAB"      :  "$BORROWER_TITLE_FAB",
    "BORROWER_SHELF_FAB"      :  "$BORROWER_SHELF_FAB",
    "BORROWER_PILE_FAB"       :  "$BORROWER_PILE_FAB",
    "BORROWER_COLLECTOR_FAB"  :  "$BORROWER_COLLECTOR_FAB",
    "BORROWER_THRESHOLD_FAB"  :  "$BORROWER_THRESHOLD_FAB",
    "BORROWER_PRICEPOOL_FAB"  :  "$BORROWER_PRICEPOOL_FAB",
    "BORROWER_CEILING_FAB"    :  "$BORROWER_CEILING_FAB",
    "BORROWER_TITLE"          :  "0x$(seth call $BORROWER_DEPLOYER 'title()(address)')",
    "BORROWER_SHELF"          :  "0x$(seth call $BORROWER_DEPLOYER 'shelf()(address)')",
    "BORROWER_CEILING"        :  "0x$(seth call $BORROWER_DEPLOYER 'ceiling()(address)')",
    "BORROWER_COLLECTOR"      :  "0x$(seth call $BORROWER_DEPLOYER 'collector()(address)')",
    "BORROWER_THRESHOLD"      :  "0x$(seth call $BORROWER_DEPLOYER 'threshold()(address)')",
    "BORROWER_PRICE_POOL"     :  "0x$(seth call $BORROWER_DEPLOYER 'pricePool()(address)')"
}
EOF