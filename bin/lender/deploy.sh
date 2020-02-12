#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util/util.sh

cd $BIN_DIR

message Deploy Lender

DEPLOYMENT_FILE="./../deployments/addresses_$(seth chain).json"
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

message Check or Deploy Lender Fabs

# check or deploy default fabs
[[ -z "$OPERATOR_FAB" ]] && OPERATOR_FAB=$(seth send --create ./../out/WhitelistOperatorFab.bin 'WhitelistOperatorFab()')
[[ -z "$ASSESSOR_FAB" ]] && ASSESSOR_FAB=$(seth send --create ./../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
[[ -z "$DISTRIBUTOR_FAB" ]] && DISTRIBUTOR_FAB=$(seth send --create ./../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
[[ -z "$TRANCHE_FAB" ]] && TRANCHE_FAB=$(seth send --create ./../out/TrancheFab.bin 'TrancheFab()')

[[ -z "$SENIOR_TRANCHE_FAB" ]] && SENIOR_TRANCHE_FAB=$ZERO_ADDRESS
[[ -z "$SENIOR_OPERATOR_FAB" ]] && SENIOR_OPERATOR_FAB=$ZERO_ADDRESS

success_msg Lender Fabs ready
TOKEN_AMOUNT_FOR_ONE=$(seth --to-uint256 1)

# backer allows lender to take currency

export DEPLOYER=$(seth send --create ./../out/LenderDeployer.bin 'LenderDeployer(address,address,uint,address,address,address,address,address,address)' $ROOT_CONTRACT $TINLAKE_CURRENCY $TOKEN_AMOUNT_FOR_ONE $TRANCHE_FAB $ASSESSOR_FAB $OPERATOR_FAB $DISTRIBUTOR_FAB $SENIOR_TRANCHE_FAB $SENIOR_OPERATOR_FAB)

seth send $DEPLOYER 'deployAssessor()'
seth send $DEPLOYER 'deployDistributor()'
seth send $DEPLOYER 'deployJuniorTranche()'
seth send $DEPLOYER 'deployJuniorOperator()'

if [ "$SENIOR_TRANCHE_FAB"  !=  "$ZERO_ADDRESS" ]; then
    seth send $DEPLOYER 'deploySeniorTranche()'
    seth send $DEPLOYER 'deploySeniorOperator()'
fi

seth send $DEPLOYER 'deploy()'

success_msg Lender Contracts deployed

#touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "LENDER_DEPLOYER"           : "$DEPLOYER",
    "OPERATOR_FAB"       :  "$OPERATOR_FAB",
    "ASSESSOR_FAB"       :  "$ASSESSOR_FAB",
    "DISTRIBUTOR_FAB"    :  "$DISTRIBUTOR_FAB",
    "TRANCHE_FAB"        :  "$TRANCHE_FAB",
    "SENIOR_TRANCHE_FAB" :  "$SENIOR_TRANCHE_FAB",
    "SENIOR_OPERATOR_FAB":  "$SENIOR_OPERATOR_FAB",
    "JUNIOR_OPERATOR"    :  "0x$(seth call $DEPLOYER 'juniorOperator()(address)')",
    "JUNIOR"             :  "0x$(seth call $DEPLOYER 'junior()(address)')",
    "SENIOR"             :  "0x$(seth call $DEPLOYER 'senior()(address)')",
    "SENIOR_OPERATOR"    :  "0x$(seth call $DEPLOYER 'seniorOperator()(address)')",
    "DISTRIBUTOR"        :  "0x$(seth call $DEPLOYER 'distributor()(address)')",
    "ASSESSOR"           :  "0x$(seth call $DEPLOYER 'assessor()(address)')"
}
EOF