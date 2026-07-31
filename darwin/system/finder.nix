{
  self,
  system,
  primaryUser,
  host,
  lib,
  ...
}:
let
  primaryHome = "/Users/${primaryUser}";
  trustedApps = [
    # Directories or .app bundles to auto-trust so Gatekeeper/quarantine
    # prompts stay out of the way. Add entries here when new GUI apps are
    # managed via this flake.
    "/Applications"
    "/Applications/Nix Apps"
    "${primaryHome}/Applications"
    "${primaryHome}/Applications/Home Manager Apps"
  ];
  trustedAppsShell = lib.concatStringsSep " " (map lib.escapeShellArg trustedApps);
  gatekeeperLabel = "NixTrustedApps";
  logPrefix = "> [Gatekeeper]";
in
{
  system.defaults.finder = {
    AppleShowAllFiles = true;
    AppleShowAllExtensions = true;
    _FXShowPosixPathInTitle = true;
    ShowPathbar = true;
    ShowStatusBar = true;
  };

  system.activationScripts.unquarantineTrustedApps.text = ''
    echo "${logPrefix} ensuring trusted GUI apps remain approved"

    trust_app() {
      local target="$1"
      [ -e "$target" ] || return 0
      echo "${logPrefix} trusting $target"
      if xattr -p com.apple.quarantine "$target" >/dev/null 2>&1; then
        xattr -dr com.apple.quarantine "$target" >/dev/null 2>&1 || true
      fi
      if command -v spctl >/dev/null 2>&1; then
        spctl --add --label ${gatekeeperLabel} "$target" >/dev/null 2>&1 || true
      fi
    }

    process_entry() {
      local entry="$1"
      [ -e "$entry" ] || return 0
      case "$entry" in
        *.app)
          trust_app "$entry"
          ;;
        *)
          if [ -d "$entry" ]; then
            shopt -s nullglob 2>/dev/null || true
            for candidate in "$entry"/*.app; do
              [ -e "$candidate" ] || continue
              trust_app "$candidate"
            done
            shopt -u nullglob 2>/dev/null || true
          fi
          ;;
      esac
    }

    for entry in ${trustedAppsShell}; do
      process_entry "$entry"
    done
  '';
}
