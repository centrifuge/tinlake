all    :; dapp build
clean  :; dapp clean
update:
	dapp update
test: update
	dapp test
deploy :; dapp create TinlakeMakerLib

export DAPP_SOLC_VERSION=0.5.12
