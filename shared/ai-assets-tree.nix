# Immutable union trees and exact prior-consumer bytes for ownership bootstrap.
{ lib, pkgs }:
let
  # Historical inputs are ownership evidence, not a second active runtime.
  # Read the prior complete source/lock so third-party and local assets cannot
  # accidentally be bootstrapped from today's replacement bytes.
  priorFlake = builtins.getFlake "github:glats/nixos-hosts/4750736cd68f517a871ac7448639c94546472390";
  priorRepo = priorFlake.outPath;
  priorPkgs = priorFlake.packages.${pkgs.stdenv.hostPlatform.system};
  priorAssets = priorPkgs.gentle-ai-assets;
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
  inherit
    tree
    priorRepo
    priorAssets
    priorPkgs
    ;
  legacy =
    consumer: extra:
    tree "gentle-ai-2.5-owned-${consumer}" (
      [
        {
          target = "skills";
          source = "${priorAssets}/share/gentle-ai/skills";
        }
        {
          target = "skills";
          source = "${priorPkgs.caveman-assets}/share/caveman/skills";
        }
        {
          target = "skills";
          source = "${priorPkgs.ponytail-assets}/share/ponytail/skills";
        }
        {
          target = "skills";
          source = "${priorPkgs.local-ai-assets}/share/local-ai/skills";
        }
        {
          target = "skills";
          source = priorRepo + "/shared/skills";
        }
        {
          target = "commands";
          source = "${priorAssets}/share/gentle-ai/${
            if consumer == "claude" then "claude" else "opencode"
          }/commands";
        }
      ]
      ++ lib.optionals (consumer != "claude") [
        {
          target = "commands";
          source = "${priorPkgs.caveman-assets}/share/caveman/commands";
        }
        {
          target = "commands";
          source = "${priorPkgs.ponytail-assets}/share/ponytail/commands";
        }
      ]
      ++ lib.optionals (consumer == "claude") [
        {
          target = "agents";
          source = "${priorAssets}/share/gentle-ai/claude/agents";
        }
      ]
      ++ extra
    );
}
