{ pkgs }:

let
  repo = builtins.path { path = ../..; };
in
pkgs.runCommand "link-grabber-env-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.python3
    ];
  }
  ''
    cp -r ${repo} repo
    python3 repo/checks/link-grabber-env/test.py

    touch $out
  ''
