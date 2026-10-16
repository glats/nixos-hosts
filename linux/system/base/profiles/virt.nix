{ pkgs }:
with pkgs;
[
  qemu_kvm
  virt-manager
  virt-viewer
  spice-gtk

  dnsmasq
  bridge-utils
  vde2

  docker
]
