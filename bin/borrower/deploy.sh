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

export BORROWER_DEPLOYER=$(seth send --create ./../out/BorrowerDeployer.bin 'BorrowerDeployer(address,address,address,address,address,address,address,address,address,string memory,string memory)' $ROOT_CONTRACT $TITLE_FAB $SHELF_FAB $PILE_FAB $CEILING_FAB $COLLECTOR_FAB $THRESHOLD_FAB $PRICEPOOL_FAB $TINLAKE_CURRENCY "$TITLE_NAME" "$TITLE_SYMBOL")


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
    "TITLE_FAB"      :  "$TITLE_FAB",
    "SHELF_FAB"      :  "$SHELF_FAB",
    "PILE_FAB"       :  "$PILE_FAB",
    "COLLECTOR_FAB"  :  "$COLLECTOR_FAB",
    "THRESHOLD_FAB"  :  "$THRESHOLD_FAB",
    "PRICEPOOL_FAB"  :  "$PRICEPOOL_FAB",
    "CEILING_FAB"    :  "$CEILING_FAB",
    "TITLE"          :  "$(seth call $BORROWER_DEPLOYER 'title()(address)')",
    "PILE"           :  "$(seth call $BORROWER_DEPLOYER 'pile()(address)')",
    "SHELF"          :  "$(seth call $BORROWER_DEPLOYER 'shelf()(address)')",
    "CEILING"        :  "$(seth call $BORROWER_DEPLOYER 'ceiling()(address)')",
    "COLLECTOR"      :  "$(seth call $BORROWER_DEPLOYER 'collector()(address)')",
    "THRESHOLD"      :  "$(seth call $BORROWER_DEPLOYER 'threshold()(address)')",
    "PRICE_POOL"     :  "$(seth call $BORROWER_DEPLOYER 'pricePool()(address)')"
}
EOF