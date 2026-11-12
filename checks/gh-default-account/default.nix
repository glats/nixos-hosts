{ pkgs }:
let
  fakeGh = pkgs.writeShellScriptBin "gh" ''
    printf '%s\n' "$@" > "$GH_TEST_LOG"
    case "$GH_TEST_MODE" in
      success) printf '%s\n' "$6" > "$HOME/selected-account" ;;
      failure) echo 'private backend error' >&2; exit 1 ;;
      hang) trap "" TERM; while :; do sleep 1; done ;;
    esac
  '';
  activation =
    (import ../../shared/gh-default-account.nix {
      config.home.github.defaultAccount = "glats";
      config.home.github.defaultAccountFile = null;
      pkgs = pkgs // {
        gh = fakeGh;
      };
      lib = pkgs.lib // {
        hm.dag.entryAfter = _: text: text;
      };
    }).config.home.activation.ghDefaultAccount;
  script = pkgs.writeShellScript "test-gh-default-account" activation;
in
pkgs.runCommand "gh-default-account-check" { } ''
  ${pkgs.bash}/bin/bash ${./test.sh} ${script} ${pkgs.coreutils}/bin/timeout ${pkgs.bash}/bin/bash ${
    if pkgs.stdenv.hostPlatform.isLinux then "linux" else ""
  }
  touch $out
''
