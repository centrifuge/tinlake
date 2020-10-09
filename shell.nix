let
  pkgs = import (builtins.fetchGit rec {
    name = "dapptools-${rev}";
    url = https://github.com/dapphub/dapptools;
    rev = "932e20da95d0c470ec97795e2e461f56a9234866";
  }) {};

in
  pkgs.mkShell {
    src = null;
    name = "tinlake-maker-lib";
    buildInputs = with pkgs; [
      pkgs.dapp
    ];
  }
