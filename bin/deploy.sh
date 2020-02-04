#! /usr/bin/env bash

BIN_DIR=${BIN_DIR:-$(cd "${0%/*}"&&pwd)}
source $BIN_DIR/util/env.sh
cd BIN_DR

message Start Tinlake deployment

build_contracts "./.."
