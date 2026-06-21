# Remote desktop client launchers — unified module for all remote connections.
#
# Deploys .desktop launchers and Remmina profiles with shared defaults.
# Settings common to all connections are defined once in Nix and merged
# into each .remmina profile.  This avoids the URI limitation where
# Remmina forces sound=off and ignores other defaults.
#
# Password storage: Remmina uses libsecret (gnome-keyring) to persist
# credentials.  The `disablepasswordstoring=0` flag in each profile
# allows the libsecret plugin to save the password to the user's
# default keyring collection on first connect.  The keyring daemon
# itself is enabled system-wide by `modules/hardware/keyring.nix`
# (services.gnome.gnome-keyring.enable) and unlocked via PAM on
# lightdm/xrdp-sesman logins.  `pkgs.libsecret` is added to
# home.packages so the libsecret shared library is always resolvable
# in the user session even if a host config drops the system-level
# keyring module.
{ lib, pkgs, ... }:

let
  # Settings common to ALL remote desktop connections.
  commonDefaults = {
    scale = 0;
    viewmode = 1;
    window_maximize = 1;
    keyboard_grab = 0;
    disableclipboard = 0;
    resolution_mode = 2;
    network = "none";
    ignore-tls-errors = 1;
    disableautoreconnect = 0;
    glyph-cache = 0;
    rdp_idle_keypress_combo = 1;
    rdp_idle_keypress_time = "No";
    disable-smooth-scrolling = 0;
    preferipv6 = 0;
    console = 0;
    multimon = 0;
    span = 0;
    sharesmartcard = 0;
    shareprinter = 0;
    shareparallel = 0;
    shareserial = 0;
    enable-autostart = 0;
    profile-lock = 0;
    disablepasswordstoring = 0;
    allow_empty_pass = 0;
    cert_ignore = 0;
    old-license = 0;
    assistance_mode = 0;
    pth = "";
    multitransport = 0;
    disable_fastpath = 0;
    left-handed = 0;
    gwtransp = "http";
    gateway_usage = 0;
    websockets = 0;
    forceipvx = 0;
    useproxyenv = 0;
    no-suppress = 0;
    timeout = "";
    rdp_mouse_jitter = "No";
    rdp_reconnect_attempts = "";
    restricted-admin = 0;
    force_multimon = 0;
    base-cred-for-gw = 0;
    relax-order-checks = 0;
    serialpermissive = 0;
    ssh_tunnel_enabled = 0;
    ssh_tunnel_loopback = 0;
    ssh_tunnel_auth = 0;
    smartcard-logon = 0;
    labels = "";
    password = ".";
    notes_text = "";
    domain = "";
    security = "";
    loadbalanceinfo = "";
    clientbuild = "";
    clientname = "";
    exec = "";
    execpath = "";
    precommand = "";
    postcommand = "";
    disconnect-prompt = 0;
    monitorids = "";
    resolution_width = 0;
    resolution_height = 0;
    usb = "";
    microphone = "";
    dvc = "";
    vc = "";
    rdp2tcp = "";
    parallelpath = "";
    parallelname = "";
    serialpath = "";
    serialname = "";
    serialdriver = "";
    printer_overrides = "";
    tls-seclevel = "";
    smartcardname = "";
    gateway_server = "";
    gateway_username = "";
    gateway_password = "";
    gateway_domain = "";
    ssh_tunnel_server = "";
    ssh_tunnel_username = "";
    ssh_tunnel_privatekey = "";
    ssh_tunnel_certfile = "";
    ssh_tunnel_password = "";
    ssh_tunnel_passphrase = "";
    ssh_tunnel_command = "";
    ssh_tunnel_command_args = "";
    smartcard_pin = "";
    freerdp_log_level = "INFO";
  };

  # RDP-specific defaults (merge on top of common)
  rdpDefaults = commonDefaults // {
    protocol = "RDP";
    colordepth = 99;
    sound = "local";
    audio-output = "sys:pulse";
    username = "glats";
    drive = "/home/glats";
    quality = 0;
  };

  # VNC-specific defaults (merge on top of common)
  vncDefaults = commonDefaults // {
    protocol = "VNC";
    colordepth = "";
    sound = "";
    audio-output = "";
    drive = "";
    username = "";
    showcursor = 0;
    disableencryption = 0;
    disableserverbell = 0;
    disableserverinput = 0;
    tightencoding = 0;
    aspect_ratio = "";
    encodings = "";
    proxy = "";
  };

  # Generate a .remmina file from a base attrset + per-host overrides.
  mkRemminaProfile =
    base: overrides:
    let
      settings = base // overrides;
      lines = lib.mapAttrsToList (k: v: "${k}=${toString v}") settings;
    in
    "[remmina]\n${lib.concatStringsSep "\n" lines}\n";

  # Desktop entry text (common shape)
  mkDesktop =
    { name
    , comment
    , exec
    ,
    }:
    ''
      [Desktop Entry]
      Type=Application
      Name=${name}
      Comment=${comment}
      Exec=${exec}
      TryExec=${pkgs.remmina}/bin/remmina
      Icon=${pkgs.remmina}/share/icons/hicolor/scalable/apps/org.remmina.Remmina.svg
      Categories=Network;RemoteAccess;
      Terminal=false
      StartupWMClass=remmina
    '';

in
{
  # === Global Remmina preferences ===
  # The [remmina] section inside remmina.pref acts as a default template
  # for *new* connections created from URIs.  It is NOT used when loading
  # a .remmina file directly, which is why every profile below embeds the
  # full defaults via mkRemminaProfile.
  xdg.configFile."remmina/remmina.pref".text = ''
    [remmina_pref]
    datadir_path=/home/glats/.local/share/remmina
    save_view_mode=true
    confirm_close=false
    main_maximize=true
    hide_connection_toolbar=true
    hide_searchbar=true
    hide_toolbar=true
    always_show_tab=false
    tab_mode=3
    scale_quality=3
    default_action=0
    resolutions=640x480,800x600,1024x768,1280x960,1920x1080
    rdp_keyboard_layout=40A

    [remmina]
    name=
    ignore-tls-errors=1
  '';

  # libsecret is required by Remmina's glibsecret plugin (the
  # remmina-plugin-secret.so) to read/write passwords in the user's
  # default keyring collection.  The plugin is built into the
  # remmina package (buildInputs includes libsecret) but the library
  # must be present in the user environment for D-Bus activation to
  # resolve the secret schema.  The system-level keyring module
  # (modules/hardware/keyring.nix) already installs libsecret, but
  # adding it here makes the dependency explicit at the HM boundary
  # and survives host configs that drop the hardware module.
  home.packages = [
    pkgs.remmina
    pkgs.libsecret
  ];

  home.file = {
    # === RDP profiles ===
    ".local/share/remmina/rdp-rog.remmina" = {
      text = mkRemminaProfile rdpDefaults {
        name = "rog";
        server = "172.16.0.5";
      };
    };
    ".local/share/remmina/rdp-oneplus5.remmina" = {
      text = mkRemminaProfile rdpDefaults {
        name = "oneplus5";
        server = "172.16.0.12";
        colordepth = 66;
      };
    };
    ".local/share/remmina/rdp-thinkcentre.remmina" = {
      text = mkRemminaProfile rdpDefaults {
        name = "thinkcentre";
        server = "172.16.0.11";
      };
    };

    # === VNC profiles ===
    ".local/share/remmina/vnc-t14.remmina" = {
      text = mkRemminaProfile vncDefaults {
        name = "t14";
        server = "172.16.0.109:5900";
      };
    };
    ".local/share/remmina/vnc-mact2.remmina" = {
      text = mkRemminaProfile vncDefaults {
        name = "mact2";
        server = "mact2.local";
      };
    };

    # === Desktop launchers ===
    ".local/share/applications/remote-rog.desktop" = {
      text = mkDesktop {
        name = "rog";
        comment = "RDP connection to 172.16.0.5";
        exec = "${pkgs.remmina}/bin/remmina -c /home/glats/.local/share/remmina/rdp-rog.remmina";
      };
    };
    ".local/share/applications/remote-oneplus5.desktop" = {
      text = mkDesktop {
        name = "oneplus5";
        comment = "RDP connection to 172.16.0.12";
        exec = "${pkgs.remmina}/bin/remmina -c /home/glats/.local/share/remmina/rdp-oneplus5.remmina";
      };
    };
    ".local/share/applications/remote-thinkcentre.desktop" = {
      text = mkDesktop {
        name = "thinkcentre";
        comment = "RDP connection to 172.16.0.11";
        exec = "${pkgs.remmina}/bin/remmina -c /home/glats/.local/share/remmina/rdp-thinkcentre.remmina";
      };
    };
    ".local/share/applications/remote-t14.desktop" = {
      text = mkDesktop {
        name = "t14";
        comment = "VNC connection to 172.16.0.109:5900";
        exec = "${pkgs.remmina}/bin/remmina -c /home/glats/.local/share/remmina/vnc-t14.remmina";
      };
    };
    ".local/share/applications/remote-mact2.desktop" = {
      text = mkDesktop {
        name = "mact2";
        comment = "VNC connection to mact2.local";
        exec = "${pkgs.remmina}/bin/remmina -c /home/glats/.local/share/remmina/vnc-mact2.remmina";
      };
    };
  };
}
