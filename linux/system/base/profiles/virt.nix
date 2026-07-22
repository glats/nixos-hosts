# Virtualization profile
# Tools for running virtual machines and managing containers.
{ pkgs }:
with pkgs;
[
  # KVM/QEMU stack
  qemu_kvm
  virt-manager
  virt-viewer
  spice-gtk

  # Networking for VMs
  dnsmasq
  bridge-utils
  vde2

  # Container runtime
  docker
]
