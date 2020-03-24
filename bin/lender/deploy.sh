#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util/util.sh

cd $BIN_DIR

message Deploy Lender

DEPLOYMENT_FILE="./../deployments/addresses_$(seth chain).json"
ZERO_ADDRESS=0x0000000000000000000000000000000000000000

message Check or Deploy Lender Fabs

# check or deploy default fabs
[[ -z "$OPERATOR_FAB" ]] && OPERATOR_FAB=$(seth send --create ./../out/AllowanceOperatorFab.bin 'AllowanceOperatorFab()')
[[ -z "$ASSESSOR_FAB" ]] && ASSESSOR_FAB=$(seth send --create ./../out/DefaultAssessorFab.bin 'DefaultAssessorFab()')
[[ -z "$DISTRIBUTOR_FAB" ]] && DISTRIBUTOR_FAB=$(seth send --create ./../out/DefaultDistributorFab.bin 'DefaultDistributorFab()')
[[ -z "$TRANCHE_FAB" ]] && TRANCHE_FAB=$(seth send --create ./../out/TrancheFab.bin 'TrancheFab()')

[[ -z "$SENIOR_TRANCHE_FAB" ]] && SENIOR_TRANCHE_FAB=$ZERO_ADDRESS
[[ -z "$SENIOR_OPERATOR_FAB" ]] && SENIOR_OPERATOR_FAB=$ZERO_ADDRESS

success_msg Lender Fabs ready
TOKEN_AMOUNT_FOR_ONE=$(seth --to-uint256 1)

# backer allows lender to take currency

export LENDER_DEPLOYER=$(seth send --create ./../out/LenderDeployer.bin 'LenderDeployer(address,address,uint,address,address,address,address,address,address)' $ROOT_CONTRACT $TINLAKE_CURRENCY $TOKEN_AMOUNT_FOR_ONE $TRANCHE_FAB $ASSESSOR_FAB $OPERATOR_FAB $DISTRIBUTOR_FAB $SENIOR_TRANCHE_FAB $SENIOR_OPERATOR_FAB)

seth send $LENDER_DEPLOYER 'deployAssessor()'
seth send $LENDER_DEPLOYER 'deployDistributor()'
seth send $LENDER_DEPLOYER 'deployJuniorTranche()'
seth send $LENDER_DEPLOYER 'deployJuniorOperator()'

if [ "$SENIOR_TRANCHE_FAB"  !=  "$ZERO_ADDRESS" ]; then
    seth send $LENDER_DEPLOYER 'deploySeniorTranche()'
    seth send $LENDER_DEPLOYER 'deploySeniorOperator()'
fi

seth send $LENDER_DEPLOYER 'deploy()'

success_msg Lender Contracts deployed

JUNIOR="$(seth call $LENDER_DEPLOYER 'junior()(address)')"
JUNIOR_TOKEN="$(seth call $JUNIOR 'token()(address)')"
SENIOR="$(seth call $LENDER_DEPLOYER 'senior()(address)')"

if [ "$SENIOR_TRANCHE_FAB"  !=  "$ZERO_ADDRESS" ]; then
    SENIOR_TOKEN="$(seth call $SENIOR 'token()(address)')"
else
    SENIOR_TOKEN="$ZERO_ADDRESS"
fi

#touch $DEPLOYMENT_FILE
addValuesToFile $DEPLOYMENT_FILE <<EOF
{
    "LENDER_DEPLOYER"    :  "$LENDER_DEPLOYER",
    "OPERATOR_FAB"       :  "$OPERATOR_FAB",
    "ASSESSOR_FAB"       :  "$ASSESSOR_FAB",
    "DISTRIBUTOR_FAB"    :  "$DISTRIBUTOR_FAB",
    "TRANCHE_FAB"        :  "$TRANCHE_FAB",
    "SENIOR_TRANCHE_FAB" :  "$SENIOR_TRANCHE_FAB",
    "SENIOR_OPERATOR_FAB":  "$SENIOR_OPERATOR_FAB",
    "JUNIOR_OPERATOR"    :  "$(seth call $LENDER_DEPLOYER 'juniorOperator()(address)')",
    "JUNIOR"             :  "$JUNIOR",
    "JUNIOR_TOKEN"       :  "$JUNIOR_TOKEN",
    "SENIOR"             :  "$SENIOR",
    "SENIOR_TOKEN"       :  "$SENIOR_TOKEN",
    "SENIOR_OPERATOR"    :  "$(seth call $LENDER_DEPLOYER 'seniorOperator()(address)')",
    "DISTRIBUTOR"        :  "$(seth call $LENDER_DEPLOYER 'distributor()(address)')",
    "ASSESSOR"           :  "$(seth call $LENDER_DEPLOYER 'assessor()(address)')"
}
EOF
