{
  self,
  system,
  primaryUser,
  host,
  lib,
  ...
}:
{
  imports = [
    ./finder.nix
    ./dock.nix
    ./security.nix
  ];

  services = {
    openssh = {
      enable = true;
    };

  };

  system = {
    stateVersion = 6;
    configurationRevision = self.rev or self.dirtyRev or null;

    startup.chime = false;

    defaults = {
      trackpad = {
        Clicking = true;
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
      };
      CustomSystemPreferences."com.apple.network.local-network" = {
        AllowedEthernetLocalNetworkAddresses = [ "172.16.0.0/12" ];
      };

      NSGlobalDomain = {
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        AppleInterfaceStyle = "Dark";
        _HIHideMenuBar = false;
        "com.apple.mouse.tapBehavior" = 1;
      };
    };
  };

  system.activationScripts.setDefaultBrowser.text = ''
    if command -v defaultbrowser >/dev/null 2>&1; then
      echo "> Ensuring default browser is Microsoft Edge (com.microsoft.edgemac)"
      # Prefer bundle ID for reliability
      defaultbrowser com.microsoft.edgemac || true
    fi
  '';

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
