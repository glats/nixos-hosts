# Base system profile — host-agnostic shared packages.
# Suite-specific packages (MATE, GNOME) live in profiles/mate.nix and
# profiles/gnome.nix, selected by the my.desktop.suite option.
# - CLI utilities (file, network, archive, process, nix tooling)
# - Desktop applications (terminals, themes, screenshot tools)
# - System utilities (git, fan control, xrdp audio passthrough module)
{ pkgs }:
with pkgs;
[
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
  remmina

  # System utilities (hardware + xrdp audio)
  asus-fan-control
  pipewire-module-xrdp
]
