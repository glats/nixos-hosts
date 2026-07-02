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

  # touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Core remote access services (SSH + built-in Screen Sharing / VNC)
  services = {
    # Enable OpenSSH (Remote Login). Uses macOS launchd-provided sshd.
    openssh = {
      enable = true;
      # NOTE: nix-darwin OpenSSH module (unlike NixOS) does not expose a generic
      # `settings` attrset. For custom sshd_config lines you can use
      # `services.openssh.extraConfig` if needed, e.g.:
      # extraConfig = ''
      #   PermitRootLogin no
      #   PasswordAuthentication yes
      # '';
    };

    # Screen Sharing (VNC) has no native nix-darwin module; we start/ensure
    # the launchd daemon via the activation hook below instead of a module option.
  };

  # system defaults and preferences
  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      loginwindow = {
        GuestEnabled = false;
        DisableConsoleAccess = true;
      };

      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        _FXShowPosixPathInTitle = true;
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      CustomUserPreferences = {
        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          ScheduleFrequency = 1;
          AutomaticDownload = 1;
          CriticalUpdateInstall = 1;
        };
        "com.apple.AdLib" = {
          allowApplePersonalizedAdvertising = false;
        };
        "com.apple.CoreBrightness" = {
          AutomaticDisplayBrightness = 0;
          CBTrueToneEnabled = 0;
        };
        "com.apple.dock" = {
          mru-spaces = false;
        };
      };
      CustomSystemPreferences."com.apple.network.local-network" = {
        AllowedEthernetLocalNetworkAddresses = [ "172.16.0.0/12" ];
      };
      dock = {
        autohide = true;
        show-recents = false;
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        AppleInterfaceStyle = "Dark";
        # Hide the native macOS menu bar so a custom status bar (e.g. spacebar)
        # can be used as the visible top bar. This mirrors the GUI setting
        # "Automatically hide and show the menu bar".
        _HIHideMenuBar = true;
      };
      # smb.NetBIOSName omitted: writing to com.apple.smb.server requires
      # entitlements the activation script doesn't have; it exits 1 under
      # set -e and aborts activation before Homebrew bundle runs.
      # The name is already "mact2" (matches the hostname) so no effect.
    };
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

  # Configure macOS Application Firewall to allow SSH incoming connections
  system.activationScripts.firewallSSH.text = ''
    echo "> Configuring firewall for SSH access"
    # Allow sshd-keygen-wrapper through the Application Firewall
    # This is the binary that handles SSH connections on macOS
    SSHD_WRAPPER="/usr/libexec/sshd-keygen-wrapper"
    if [ -f "$SSHD_WRAPPER" ]; then
      /usr/libexec/ApplicationFirewall/socketfilterfw --add "$SSHD_WRAPPER" >/dev/null 2>&1 || true
      /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "$SSHD_WRAPPER" >/dev/null 2>&1 || true
      echo "  - SSH ($SSHD_WRAPPER) allowed through firewall"
    fi
    # Also ensure /usr/sbin/sshd is allowed if it exists
    if [ -f "/usr/sbin/sshd" ]; then
      /usr/libexec/ApplicationFirewall/socketfilterfw --add "/usr/sbin/sshd" >/dev/null 2>&1 || true
      /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp "/usr/sbin/sshd" >/dev/null 2>&1 || true
      echo "  - /usr/sbin/sshd allowed through firewall"
    fi
  '';

  # Set default browser to Microsoft Edge during activation (idempotent)
  system.activationScripts.setDefaultBrowser.text = ''
    if command -v defaultbrowser >/dev/null 2>&1; then
      echo "> Ensuring default browser is Microsoft Edge (com.microsoft.edgemac)"
      # Prefer bundle ID for reliability
      defaultbrowser com.microsoft.edgemac || true
    fi
  '';

  # Try to apply settings immediately after activation to avoid logout/login
  # `postUserActivation` was removed; activation now runs as root. Run
  # activateSettings -u for each user by switching to that user (sudo -u).
  system.activationScripts.postActivation.text = ''
    # activateSettings needs to run as the target user so that per-user
    # settings are applied. Iterate over /Users and run it for each real user.
    for dir in /Users/*; do
      [ -d "$dir" ] || continue
      user="$(basename "$dir")"
      # Skip common non-user directories
      case "$user" in
        Shared|Guest) continue ;;
      esac
      if id "$user" >/dev/null 2>&1; then
        echo "> Applying settings for user: $user"
        sudo -u "$user" /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
      fi
    done

    echo "> Verifying remote access services (SSH + Screen Sharing)"
    ensure_service() {
      local label="$1"
      # Load/enable if missing (LaunchDaemon domain 'system')
      if ! launchctl print system/"$label" >/dev/null 2>&1; then
        echo "  - Loading $label"
        launchctl enable system/"$label" || true
        # If still not present, try an explicit bootstrap from the stock LaunchDaemons path
        if ! launchctl print system/"$label" >/dev/null 2>&1; then
          # Use $label without Nix interpolation to avoid evaluation error
          local plist="/System/Library/LaunchDaemons/$label.plist"
            if [ -f "$plist" ]; then
              echo "  - Bootstrapping $label via $plist"
              launchctl bootstrap system "$plist" || true
            fi
        fi
      fi
      # Kickstart if not running
      if ! launchctl print system/"$label" 2>/dev/null | grep -q "state = running"; then
        echo "  - Starting $label"
        launchctl kickstart -k system/"$label" || true
      else
        echo "  - $label already running"
      fi
    }

    # OpenSSH daemon label
    ensure_service com.openssh.sshd
    # macOS Screen Sharing (built-in VNC) daemon label
    ensure_service com.apple.screensharing
    # SMB file sharing daemon (File Sharing) so the host is reachable via smb://
    ensure_service com.apple.smbd
  '';
}
