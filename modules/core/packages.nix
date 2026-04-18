{ config, lib, pkgs, ... }:

let
  isRog = config.networking.hostName == "rog";

  matePkgs = with pkgs; [
    atril
    caja
    engrampa
    eom
    marco
    pluma
    mate-applets
    mate-backgrounds
    mate-calc
    mate-control-center
    mate-desktop
    mate-icon-theme
    mate-media
    mate-menus
    mate-panel
    mate-power-manager
    mate-screensaver
    mate-session-manager
    mate-settings-daemon
    mate-system-monitor
    mate-terminal
    mate-themes
    mate-user-guide
    mate-utils
    mate-netbook
    mate-notification-daemon
    mate-polkit
    mate-sensors-applet
    mate-user-share
  ];

  cliTools = with pkgs; [
    fzf
    bat
    curl
    wget
    fastfetch
    htop
    btop
    jq
    lsd
    util-linux
    nil
    nixpkgs-fmt
    statix
    deadnix
    coreutils
    findutils
    binutils
    pciutils
    usbutils
    lshw
    file
    tree
    ncdu
    duf
    iproute2
    iputils
    dnsutils
    nettools
    nmap
    wakeonlan
    ethtool
    aria2
    zip
    unzip
    p7zip
    rar
    unrar
    xz
    iotop
    iftop
    nethogs
    lsof
    sysstat
    nix-search-cli
    systemctl-tui
    cmatrix
    dex
    sshfs
    libsecret
    google-cloud-sdk
    xclip
    imagemagick
    home-manager
    ffmpeg
    avahi
    tcpdump
  ];

  devTooling = with pkgs; [
    gcc
    gnumake
    cmake
    meson
    ninja
    autoconf
    automake
    libtool
    pkg-config
    go
    nodejs
    codex
    dotnet-sdk_8
    godot_4-mono
  ];

  desktopApps = with pkgs; [
    ghostty
    mpv
    wiremix
    flatpak
    meld
    xdg-user-dirs
    windsurf
    hicolor-icon-theme
    papirus-icon-theme
    materia-theme
    gnome-themes-extra
    gtk-engine-murrine
    adwaita-icon-theme
    flameshot
    copyq
    conky
    scrot
    networkmanagerapplet
    gparted
    hexchat  # IRC client
  ];

  mediaSupport = with pkgs; [
    intel-vaapi-driver
    libva-vdpau-driver
    libva-utils
    intel-gpu-tools
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
  ];

  virtualization = with pkgs; [
    qemu_kvm
    virt-manager
    virt-viewer
    spice-gtk
    dnsmasq
    bridge-utils
    vde2
  ];

  browsers = with pkgs; [
    google-chrome
    microsoft-edge
    chromium
    brave
  ];
in

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    nodejs_22
    bun
    docker
    opencode
    asus-fan-control
    pipewire-module-xrdp
  ] ++ matePkgs ++ cliTools ++ devTooling ++ desktopApps ++ mediaSupport ++ browsers ++ virtualization;
}
