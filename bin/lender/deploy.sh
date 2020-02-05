#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util/util.sh

cd $BIN_DIR

message Deploy Lender

DEPLOYMENT_FILE="./../deployments/addresses_$(seth chain).json"
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

message Check or Deploy Lender Fabs

# check or deploy default fabs
[[ -z "$LENDER_OPERATOR_FAB" ]] && LENDER_OPERATOR_FAB=$(seth send --create ./../out/WhitelistOperatorFab.bin 'WhitelistOperator()')
[[ -z "$LENDER_ASSESSOR_FAB" ]] && LENDER_ASSESSOR_FAB=$(seth send --create ./../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
[[ -z "$LENDER_DISTRIBUTOR_FAB" ]] && LENDER_DISTRIBUTOR_FAB=$(seth send --create ./../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
[[ -z "$LENDER_TRANCHE_FAB" ]] && LENDER_TRANCHE_FAB=$(seth send --create ./../out/TrancheFab.bin 'TrancheFab()')

[[ -z "$LENDER_SENIOR_TRANCHE_FAB" ]] && LENDER_SENIOR_TRANCHE_FAB=$ZERO_ADDRESS
[[ -z "$LENDER_SENIOR_OPERATOR_FAB" ]] && LENDER_SENIOR_OPERATOR_FAB=$ZERO_ADDRESS

success_msg Lender Fabs ready
TOKEN_AMOUNT_FOR_ONE=$(seth --to-uint256 1)

# backer allows lender to take currency

export LENDER_DEPLOYER=$(seth send --create ./../out/LenderDeployer.bin 'LenderDeployer(address,address,uint,address,address,address,address,address,address)' $ROOT_CONTRACT $TINLAKE_CURRENCY $TOKEN_AMOUNT_FOR_ONE $LENDER_TRANCHE_FAB $LENDER_ASSESSOR_FAB $LENDER_OPERATOR_FAB $LENDER_DISTRIBUTOR_FAB $LENDER_SENIOR_TRANCHE_FAB $LENDER_SENIOR_OPERATOR_FAB)

seth send $LENDER_DEPLOYER 'deployAssessor()'
seth send $LENDER_DEPLOYER 'deployDistributor()'
seth send $LENDER_DEPLOYER 'deployJuniorTranche()'
seth send $LENDER_DEPLOYER 'deployJuniorOperator()'

if [ "$LENDER_SENIOR_TRANCHE_FAB"  !=  "$ZERO_ADDRESS" ]; then
    seth send $LENDER_DEPLOYER 'deploySeniorTranche()'
    seth send $LENDER_DEPLOYER 'deploySeniorOperator()'
fi

seth send $LENDER_DEPLOYER 'deploy()'

success_msg Lender Contracts deployed

#touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "LENDER_DEPLOYER"           : "$LENDER_DEPLOYER",
    "LENDER_OPERATOR_FAB"       :  "$LENDER_OPERATOR_FAB",
    "LENDER_ASSESSOR_FAB"       :  "$LENDER_ASSESSOR_FAB",
    "LENDER_DISTRIBUTOR_FAB"    :  "$LENDER_DISTRIBUTOR_FAB",
    "LENDER_TRANCHE_FAB"        :  "$LENDER_TRANCHE_FAB",
    "LENDER_SENIOR_TRANCHE_FAB" :  "$LENDER_SENIOR_TRANCHE_FAB",
    "LENDER_SENIOR_OPERATOR_FAB":  "$LENDER_SENIOR_OPERATOR_FAB",
    "LENDER_JUNIOR_OPERATOR"    :  "0x$(seth call $LENDER_DEPLOYER 'juniorOperator()(address)')",
    "LENDER_JUNIOR"             :  "0x$(seth call $LENDER_DEPLOYER 'junior()(address)')",
    "LENDER_SENIOR"             :  "0x$(seth call $LENDER_DEPLOYER 'senior()(address)')",
    "LENDER_SENIOR_OPERATOR"    :  "0x$(seth call $LENDER_DEPLOYER 'seniorOperator()(address)')",
    "LENDER_DISTRIBUTOR"        :  "0x$(seth call $LENDER_DEPLOYER 'distributor()(address)')",
    "LENDER_ASSESSOR"           :  "0x$(seth call $LENDER_DEPLOYER 'assessor()(address)')"
}
EOF