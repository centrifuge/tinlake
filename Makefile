all    :; dapp build
install     : install_solc dapp_update yarn_install
clean  :; dapp clean
update:
	dapp update
test: update
	dapp test
deploy :; dapp create TinlakeMakerLib
test_deep   :; dapp test --fuzz-runs 50000
