{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/suites/mate/default.nix
  ../../../linux/home/suites/mate-rog/default.nix
  ../../../linux/home/conky-rog.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/webcam.nix

  # Override active OpenCode provider for this host
  {
    home.opencode.activeProviderName = "opencode-go-openai";
    # OmO pilot retired 2026-09-11: agent-name routing confusion (a plain
    # "apply" routed to OmO's Sisyphus-Junior worker instead of sdd-apply).
    # Kimi-k3 orchestrator and opencode 1.18.22 stay. Re-enable with `true`
    # to restore the full pilot (docs/oh-my-openagent.md).
    # home.opencode.omo.enable = true;
  }
]
