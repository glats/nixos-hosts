# OpenWrt router upgrade

The LAN router is a Xiaomi Redmi Router AX6S (`mediatek/mt7622`, `aarch64_cortex-a53`)
reachable with `ssh root@router.lan`. It runs OpenWrt with `apk` and `owut`, and is
not managed by this flake.

Last upgrade: 25.12.5 (kernel 6.12.94) to 25.12.6 (kernel 6.12.112), 2026-11-07.

## Use `owut`, not `apk upgrade`

The rootfs is a read-only squashfs image with a small writable `/overlay` (about
88 MB). `apk upgrade` installs new package files into the overlay on top of the
image, which fills it and mixes versions of the kernel, modules and libraries.
`owut` asks the ASU server (`sysupgrade.openwrt.org`) for a fresh image with the
same package set, then flashes it keeping the configuration. Firmware and
packages end up current together and the overlay stays clean.

Reserve `apk upgrade <package>` for a single urgent security fix.

## Procedure

1. Back up the configuration to a path outside the repository. The archive
   holds WiFi keys and must never be committed:

   ```sh
   ssh root@router.lan 'sysupgrade -b -' > /tmp/opencode/router-backup-<version>.tar.gz
   ```

2. Check what would change:

   ```sh
   ssh root@router.lan 'owut check --verbose'
   ```

   Proceed only on `It is safe to proceed with an upgrade`. A default package
   reported as replaced (for example `nftables` by `nftables-json`) is normal.
   Package build failures are fine when the message says they do not affect
   this device.

3. Build and download the image. This does not touch the running system and
   takes about 95 seconds:

   ```sh
   ssh root@router.lan 'owut download -k'
   ```

4. Flash. The router reboots and SSH drops, which is expected:

   ```sh
   ssh root@router.lan 'owut install'
   ```

   `owut upgrade` runs steps 3 and 4 in one command.

5. Wait about 2 minutes, then confirm:

   ```sh
   ssh root@router.lan 'grep DISTRIB_DESCRIPTION /etc/openwrt_release; apk update; apk list -u'
   ```

   `apk list -u` must be empty after `apk update`. A non-empty list before
   updating the index is stale data, not a failed upgrade.

## Impact

Internet and WiFi are down for roughly 2 to 5 minutes because the router is the
only gateway. The upgrade happens once; configuration, DHCP settings, SSH
keys and firewall rules are preserved. Run it when nobody depends on the
connection, and from a machine that does not need the router to finish the
session.

## Recovery

Restore the backup from step 1 if configuration is lost:

```sh
scp /tmp/opencode/router-backup-<version>.tar.gz root@router.lan:/tmp/
ssh root@router.lan 'sysupgrade -r /tmp/router-backup-<version>.tar.gz && reboot'
```

If the router does not come back, use the Xiaomi/OpenWrt recovery procedure for
the AX6S (UART or the stock recovery flow) from the OpenWrt device page.
