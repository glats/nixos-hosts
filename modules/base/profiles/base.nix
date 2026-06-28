# Base system profile — host-agnostic shared packages.
# Suite-specific packages (MATE, GNOME) live in profiles/mate.nix and
# profiles/gnome.nix, selected by the my.desktop.suite option.
# - CLI utilities (file, network, archive, process, nix tooling)
# - Desktop applications (terminals, themes, screenshot tools)
# - System utilities (git, fan control, xrdp audio passthrough module)
#
# Packages that overlap with what omarchy-nix provides on t14 (suite =
# "gnome") are gated with `lib.mkIf (cfg != "gnome")` so they install
# on rog/thinkcentre but are skipped on t14. omarchy-nix already ships
# fzf, curl, wget, unzip, fastfetch, btop, coreutils, lazygit,
# lazydocker, jq, ghostty — see omarchy-nix/modules/packages.nix.
{ pkgs
, config
, lib
, ...
}:
let
  cfg = config.my.desktop.suite;
  nonGnome = p: lib.mkIf (cfg != "gnome") p;
in
with pkgs;
[
  # CLI utilities - file/archive operations
  (nonGnome fzf)
  bat
  delta
  (nonGnome curl)
  (nonGnome wget)
  aria2
  zip
  (nonGnome unzip)
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
  (nonGnome fastfetch)
  htop
  (nonGnome btop)
  iotop
  iftop
  nethogs
  lsof
  sysstat
  lshw
  pciutils
  usbutils
  util-linux
  (nonGnome coreutils)
  findutils
  binutils
  lsd
  cmatrix
  (nonGnome scrot)
  systemctl-tui
  (nonGnome xclip)
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
  (nonGnome lazygit)
  (nonGnome lazydocker)
  home-manager

  # Misc
  (nonGnome jq)
  yq
  libsecret
  google-cloud-sdk
  dex

  # Desktop applications
  (nonGnome ghostty)
  windsurf
  flatpak
  meld
  xdg-user-dirs
  hicolor-icon-theme
  papirus-icon-theme
  gnome-themes-extra
  (nonGnome gtk-engine-murrine)
  adwaita-icon-theme
  (nonGnome flameshot)
  (nonGnome copyq)
  (nonGnome gpaste)
  (nonGnome conky)
  networkmanagerapplet
  gparted
  (nonGnome hexchat)
  popsicle
  hypridle
  remmina

  # System utilities (hardware + xrdp audio)
  asus-fan-control
  pipewire-module-xrdp
]
