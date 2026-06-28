# Core system profile — host-agnostic shared packages.
# Imported by all hosts (rog, thinkcentre, t14).
# Contains: CLI utilities, Nix tooling, themes, system utilities.
# No conditions, no lib.mkIf. Suite-specific additions live in
# profiles/mate.nix and profiles/gnome.nix (selected by
# packages.nix via my.desktop.suite).
{ pkgs }:
with pkgs;
[
  # CLI utilities - file/archive operations
  bat
  delta
  aria2
  zip
  p7zip
  rar
  unrar
  xz
  file
  tree
  ncdu
  duf
  imagemagick

  # CLI utilities - system/process info
  htop
  iotop
  iftop
  nethogs
  lsof
  sysstat
  lshw
  pciutils
  usbutils
  util-linux
  findutils
  binutils
  lsd
  cmatrix
  systemctl-tui
  xxd

  # CLI utilities - networking
  iproute2
  iputils
  dnsutils
  nettools
  nmap
  wakeonlan
  ethtool
  tcpdump
  sshfs
  avahi
  thttpd
  sqlite

  # Nix tooling
  git
  nil
  nix-output-monitor
  nixpkgs-fmt
  statix
  deadnix
  nix-search-cli
  home-manager

  # Misc
  yq
  libsecret
  google-cloud-sdk
  dex

  # Desktop applications
  windsurf
  flatpak
  meld
  xdg-user-dirs
  hicolor-icon-theme
  papirus-icon-theme
  gnome-themes-extra
  adwaita-icon-theme
  networkmanagerapplet
  gparted
  popsicle
  hypridle
  remmina

  # System utilities (hardware + xrdp audio)
  asus-fan-control
  pipewire-module-xrdp
]
