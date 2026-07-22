{ config, pkgs, lib, ... }:

let
  utilLinux = pkgs.util-linux;
  coreutils = pkgs.coreutils;

  mountScript = pkgs.writeShellScriptBin "maquilinux-mount" ''
    #!/bin/bash
    export PATH="${utilLinux}/bin:${coreutils}/bin:/run/wrappers/bin:$PATH"
    set -euo pipefail

    OVERLAY=/mnt/maquilinux/merged
    BASE=/mnt/maquilinux/base
    UPPER=/mnt/maquilinux/layers/upper
    WORK=/mnt/maquilinux/layers/work

    # Check if already mounted
    if mountpoint -q $OVERLAY; then
      echo "Maqui Linux overlay already mounted"
      exit 0
    fi

    # Ensure directories exist
    mkdir -p $OVERLAY $UPPER $WORK \
      $OVERLAY/proc $OVERLAY/sys $OVERLAY/dev \
      $OVERLAY/dev/pts $OVERLAY/dev/shm \
      $OVERLAY/run $OVERLAY/workspace \
      $OVERLAY/mnt/repo

    # Mount overlay
    mount -t overlay overlay -o lowerdir=$BASE,upperdir=$UPPER,workdir=$WORK $OVERLAY

    # Bind mounts for chroot
    mount --bind /home/glats/Work/maquilinux $OVERLAY/workspace
    mount -t proc proc $OVERLAY/proc
    mount -t sysfs sysfs $OVERLAY/sys
    mount -o bind /dev $OVERLAY/dev
    mount -o bind /dev/pts $OVERLAY/dev/pts
    mount -o bind /dev/shm $OVERLAY/dev/shm
    mount --bind /mnt/maquilinux/repo $OVERLAY/mnt/repo
    mount -t tmpfs tmpfs $OVERLAY/run

    echo "Maqui Linux overlay mounted successfully"
  '';

  umountScript = pkgs.writeShellScriptBin "maquilinux-umount" ''
    #!/bin/bash
    export PATH="${utilLinux}/bin:${coreutils}/bin:/run/wrappers/bin:$PATH"
    set -euo pipefail

    OVERLAY=/mnt/maquilinux/merged

    if ! mountpoint -q $OVERLAY; then
      echo "Maqui Linux overlay not mounted"
      exit 0
    fi

    # Unmount in reverse order (lazy to handle busy mounts)
    umount -l $OVERLAY/run 2>/dev/null || true
    umount -l $OVERLAY/mnt/repo 2>/dev/null || true
    umount -l $OVERLAY/dev/shm 2>/dev/null || true
    umount -l $OVERLAY/dev/pts 2>/dev/null || true
    umount -l $OVERLAY/dev 2>/dev/null || true
    umount -l $OVERLAY/sys 2>/dev/null || true
    umount -l $OVERLAY/proc 2>/dev/null || true
    umount -l $OVERLAY/workspace 2>/dev/null || true
    umount -l $OVERLAY 2>/dev/null || true

    echo "Maqui Linux overlay unmounted"
  '';
in
{
  systemd.services.maquilinux-mounts = {
    description = "Mount Maqui Linux overlay filesystem";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${mountScript}/bin/maquilinux-mount";
      ExecStop = "${umountScript}/bin/maquilinux-umount";
    };
  };
}
