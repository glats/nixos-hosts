# Omarchy per-host options for t14.
# The omarchy NixOS module reads these values to decide themes, monitors,
# identity, browser, terminal, firewall, wayvnc, and the greeter layout.
{ ... }:

{
  # VNC server — captures Wayland screen via wlroots screencopy.
  # Runs inside Hyprland session (autostart.nix) on 0.0.0.0:5900.
  # The actual `programs.wayvnc.enable = true` lives in
  # omarchy-nix:modules/nixos/wayvnc.nix, gated by `omarchy.wayvnc.enable`
  # (set below).

  # === OMARCHY CONFIG BLOCK ===
  # Omarchy reads these options from the imported NixOS module to decide
  # which themes/monitors/identities to deploy. The full_name and
  # email_address are placeholders until sops-backed user identity is
  # wired in (tracked in proposal "Open Questions").
  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";

    # "glats" is a first-class theme in upstream omarchy-nix after
    # the native-glats PR was merged.  The colorScheme is now driven
    # by omarchy-nix from the active theme; the local
    # hosts/t14/home/theme.nix + theme-files.nix pair was removed
    # because omarchy-nix generates the theme files dynamically.
    theme = "glats";

    # WiFi: iwd standalone for impala compatibility. NM ignores wlan0
    # and handles ethernet/Docker. iwd manages connections, DHCP, and
    # DNS via systemd-resolved on its own.
    wifi.backend = "standalone-iwd";

    # Built-in 14" 1920x1080 panel; external monitors are managed by
    # monitor-hotplug-handler.sh (see hosts/t14/home/hypr/autostart.nix).
    monitors = [ "eDP-1,preferred,auto,1" ];

    # T14 delegates lid-switch handling to HDM (UPower D-Bus).
    # Disable omarchy's default lid-switch bindl to eliminate
    # dual-writer races.
    hyprland.lidSwitch.enable = false;

    # Laptop panel is 1x scale (1920x1080 native).
    scale = 1;

    browser = "brave";
    terminal = "ghostty";

    # No firewall — development machine on controlled networks.
    # REQ-003: omarchy.firewall.enable = false is the canonical way to
    # opt out of omarchy's mkIf-guarded firewall module.
    firewall.enable = false;

    # VNC server — opt-in to omarchy.wayvnc (NixOS module enables
    # programs.wayvnc + systemPackages; HM module deploys the
    # systemd user service + config file). Port 5900 + enable_pam = true
    # match upstream defaults; set explicitly here for documentation.
    wayvnc = {
      enable = true;
      # Capture the landscape AOC 2470W (DP-3) where regreet/desktop is visible.
      output = "DP-3";
    };

    # Greeter: regreet (greeter for Hyprland). Selects the regreet-based
    # login flow instead of the default tuigreet.
    greeter = {
      type = "regreet";
      # Matches "Lenovo Group Limited LEN G24-10 U5B4GWF1" from monitors below.
      # When empty (default) the selection phase is a no-op — current behaviour.
      focusMonitor = "LEN G24";
      keyboard = {
        layouts = [
          "es"
          "latam"
        ];
        # compose:caps removed: it would remap CAPS LOCK to Compose at
        # the login screen, breaking dead-key accented input there too.
        # Hyprland session's kb_options matches (no compose:caps) so the
        # greeter and the session behave identically.
        options = "grp:alt_shift_toggle";
      };
      monitors = [
        "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1"
        "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
        "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"
      ];
      cursor.theme = "Bibata-Modern-Ice";

      # Pre-login VNC: wayvnc runs inside the greeter Hyprland session
      # (on the same port 5900 as the user-session wayvnc). Remmina
      # auto-reconnects across the ~1s handoff when the user logs in.
      # Defaults for address/port/enable_pam come from omarchy-nix.
      wayvnc = {
        enable = true;
        output = "DP-3";
      };
      # Layout indicator: displays "ES"/"LATAM" on a 24px bottom waybar
      # bar at the login screen. Updates within 1s of Alt+Shift toggle.
      layoutIndicator.enable = true;
    };
  };
}
