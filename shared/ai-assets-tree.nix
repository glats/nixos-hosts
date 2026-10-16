{ lib, pkgs }:
let
  tree =
    name: entries:
    pkgs.runCommand name { } ''
        mkdir -p "$out"
      ${lib.concatMapStringsSep "\n" (entry: ''
        chmod -R u+w "$out"
          mkdir -p "$out/${entry.target}"
        if [ -d ${
          lib.escapeShellArg (
            if builtins.isPath entry.source then builtins.path { path = entry.source; } else entry.source
          )
        } ]; then
          cp -r ${
            lib.escapeShellArg (
              if builtins.isPath entry.source then builtins.path { path = entry.source; } else entry.source
            )
          }/. "$out/${entry.target}/"
          fi
      '') entries}
        chmod -R u+w "$out"
    '';
in
{
  inherit tree;
  none = pkgs.runCommand "ai-assets-no-legacy" { } "mkdir $out";
}
