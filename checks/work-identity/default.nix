{ pkgs }:

let
  repo = builtins.path { path = ../..; };
in
pkgs.runCommand "work-identity-check"
  {
    nativeBuildInputs = [
      pkgs.nix
      pkgs.python3
      pkgs.git
    ];
  }
  ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export NIX_STATE_DIR="$TMPDIR/state"
    export NIX_CONFIG="experimental-features = nix-command flakes"
    mkdir -p "$HOME" "$XDG_CACHE_HOME" "$NIX_STATE_DIR"

    cp -r ${repo} repo
    python3 repo/checks/work-identity/test.py

    touch $out
  ''
