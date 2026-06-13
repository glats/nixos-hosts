# Base system profile
# Essential packages that every Linux host gets by default:
# - MATE desktop support (not installed by services.xserver.desktopManager.mate.enable)
# - CLI utilities (file, network, archive, process, nix tooling)
# - Desktop applications (terminals, file managers, themes, screenshot tools)
# - System utilities (git, fan control, xrdp audio passthrough module)
{ pkgs }:
with pkgs;
[
  # MATE desktop support
  atril
  caja
  engrampa
  eom
  marco
  pluma
  mate-panel
  mate-sensors-applet
  mate-user-share

  # CLI utilities - file/archive operations
  fzf
  bat
  delta
  curl
  wget
  aria2
  zip
  unzip
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
  fastfetch
  htop
  btop
  iotop
  iftop
  nethogs
  lsof
  sysstat
  lshw
  pciutils
  usbutils
  util-linux
  coreutils
  findutils
  binutils
  lsd
  cmatrix
  scrot
  systemctl-tui
  xclip
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
  lazygit
  lazydocker
  home-manager

  # Misc
  jq
  yq
  libsecret
  google-cloud-sdk
  dex

  # Desktop applications
  ghostty
  windsurf
  flatpak
  meld
  xdg-user-dirs
  hicolor-icon-theme
  papirus-icon-theme
  materia-theme
  gnome-themes-extra
  gtk-engine-murrine
  adwaita-icon-theme
  flameshot
  copyq
  gpaste
  conky
  networkmanagerapplet
  gparted
  hexchat
  popsicle
  hypridle

  # System utilities (hardware + xrdp audio)
  asus-fan-control
  pipewire-module-xrdp
]
