#! /usr/bin/env bash

message() {

    echo
    echo ----------------------------------------------
    echo "$@"
    echo ----------------------------------------------
    echo
}

success_msg()
{
 echo -e "\e[0;31m Success >>> $1"
 echo -e "Default \e[92mLight green"
}
error_exit()
{
    echo -e "\e[0;31m >>> Error $@"
    exit 1
}

warning_msg()
{
    echo -e "\e[0;33m >>> Warning $@ \e[0m"
}

build_contracts()
{
    CONTRACT_FILES=1
    if [ -d "$1/out" ]; then
    # count contract abi files
    CONTRACT_FILES=$(ls $1/out | wc -l)
    fi
    # build contracts if required
    if [ "$CONTRACT_FILES" -lt  "2" ]; then
        cd ./../../
        dapp update
        dapp build --extract
    fi
    message contract build files are ready
}
