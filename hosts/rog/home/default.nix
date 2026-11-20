{ inputs }:

let
  baseModules = import ../../../linux/home/shared-modules.nix { inherit inputs; };
in
baseModules
++ [
  ../../../linux/home/remote-desktop.nix

  ../../../linux/home/suites/mate/default.nix
  ../../../linux/home/suites/mate-rog/default.nix
  ../../../linux/home/conky.nix
  ../../../linux/home/openfang.nix
  ../../../linux/home/gastown-campaigns.nix
  ../../../linux/home/webcam.nix

  {
    home.opencode.activeProviderName = "personal";
    home.opencode.compactionBuffer = "80%";
    home.gastown.campaigns.maquilinux = {
      repo = "/home/glats/Project/maquilinux";
      doltPort = 45900;
      checks = [
        "USER=agent bats tests/*.bats"
        "for f in mql scripts/*.sh lib/*.sh; do [ -f \"$f\" ] && { bash -n \"$f\" || exit 1; }; done"
      ];
    };
    home.gastown.campaigns.reimbursement = {
      autostart = false;
      repo = "/home/glats/Project/reimbursement-web";
      doltPort = 45911;
      maxPolecats = 1;
      disabledPatrols = [ "witness" ];
      checks = [ "sh scripts/check" ];
      protect = [
        "AGENTS.md"
        "README.md"
        "docs/provenance.md"
        "Makefile"
        ".golangci.yml"
        "scripts/check"
        "scripts/test-check.sh"
        "scripts/test-check-contracts.sh"
        "internal/architecture/boundaries_test.go"
      ];
    };
    home.ghostty.xrdp-optimized = true;
  }

  ({ config, ... }: {
    home.file."Guacamole".source = config.lib.file.mkOutOfStoreSymlink "/srv/glats/guacamole/drive";
  })
]
