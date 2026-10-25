# Brother DCP-1610NW network printing and scanning

`rog`, `thinkcentre`, and `t14` configure a CUPS queue named `brother`, Brother's `brscan4` network scanner backend, and Document Scanner (`simple-scan`). The device must be reachable at `brother.lan` from each client. This configuration does not activate itself.

## Use after deployment

Deploy each host through the normal, separately authorized NixOS workflow. Open Document Scanner to scan to PDF or an image, or select **Brother DCP-1610NW** in an application's print dialog. No existing default printer is changed.

Check connectivity and configuration without consuming paper or moving the scanner:

```console
getent hosts brother.lan
lpstat -p brother -v
scanimage -L
```

`scanimage -L` may contact the scanner but does not acquire an image. To inspect available resolutions and modes, use the device name returned by that command:

```console
scanimage --device-name '<device-name>' --help
```

Only when ready to consume paper or acquire a document:

```console
lp -d brother document.pdf
scanimage --device-name '<device-name>' --format=png > scan.png
```

Document Scanner can assemble manually scanned pages into a PDF. Do not assume automatic duplex, an automatic document feeder, or OCR from this configuration; these require device/application support. The copier works independently of NixOS.

The installed Document Scanner executable supplies a private `SANE_CONFIG_DIR` containing only `dll.conf` with the `brother4` backend and prefixes `LD_LIBRARY_PATH` with `/etc/sane-libs`. Its normal Rofi desktop entry and terminal command therefore use the same Brother-only scanner configuration without requiring session variables or a new login. Close any existing Document Scanner process after deploying, then reopen it.

This avoids enumerating webcams and unrelated scanner backends inside Document Scanner, but does not remove its startup device enumeration or the Brother backend's availability checks. Other SANE applications retain the global backend list. Brother model and hostname registration remain managed by the system brscan4 configuration. Additional non-Brother scanners will not appear in this application unless its private configuration is expanded or removed.

The shared Linux theme no longer imports Materia CSS into GTK4. Document Scanner additionally sets `ADW_DISABLE_PORTAL=1` for its own process so libadwaita reads the existing `org.gnome.desktop.interface color-scheme=prefer-dark` preference directly, even on MATE without a settings portal. This follows the user's dark preference rather than forcing a debug color scheme. It does not change portal behavior for other applications or install a desktop portal. GTK3 applications retain Materia, existing GTK3 contrast fixes, and Papirus icons.

## Driver and network choices

Printing uses `brlaser`'s `drv:///brlaser.drv/br1610.ppd` and the printer's raw TCP port 9100, not an assumed AirPrint endpoint. The pinned brlaser package explicitly provides a DCP-1610W-series PPD; a physical print must still confirm suitability for this NW device. Scanning uses the exact `DCP-1610NW` entry in the pinned brscan4 model database and DNS hostname registration. It does not depend on multicast discovery or a fixed numeric IP.

Keep `brother.lan` stable in local DNS. Both clients and printer need the same reachable LAN or explicitly routed access. Raw printing is unencrypted; use a trusted LAN, not Internet port forwarding. CUPS listens on localhost and default queue sharing is disabled. Existing host browsing settings are preserved. This module does not open firewall ports, export a scanner server, or change Avahi interfaces.

NixOS also enables `cups-browsed` by default with printing. This is newly enabled on `rog` and `thinkcentre`; `t14` already had it. It may discover additional queues advertised on the LAN. This module leaves that native default unchanged; localhost CUPS listening and disabled default sharing do not mean that discovery is disabled.

The printer's **Scan to PC** button is not configured. `brscan4` enables scans initiated from the computer; push scanning requires a separate supported listener and destination selection. No custom listener, email credentials, FTP server, or automatic document receiver is installed.

## macm5

No Darwin configuration or vendor software is installed. The Linux `brlaser` and `brscan4` packages are not Apple Silicon drivers. Modern macOS support for this exact model remains unverified; the Brother FAQ's references to iPrint&Scan and its Push Scan Tool apply only to compatible models.

On `macm5`, first check **System Settings > Printers & Scanners > Add Printer**. Use AirPrint only if macOS actually offers it for this printer. Otherwise check Brother's downloads for the exact model and installed macOS version before installing a driver. Network IPP support alone does not establish AirPrint compatibility. Do not select a generic PostScript/PCL driver for a host-based printer without confirmed support.

## Verification and rollback

```console
nix eval --impure --json --file tests/brother-printer.nix
nix eval --impure --json --file tests/gtk4-theme.nix
nix build --impure --file tests/simple-scan-launcher.nix --no-link
nix eval 'path:.#nixosConfigurations.rog.config.system.build.toplevel.drvPath'
nix eval 'path:.#nixosConfigurations.thinkcentre.config.system.build.toplevel.drvPath'
nix eval 'path:.#nixosConfigurations.t14.config.system.build.toplevel.drvPath'
nix flake check path:. --no-build
```

The `path:.` reference includes new, unstaged module files without staging them. Configuration evaluation is not proof of physical printing or scanning. Initial probes resolved `brother.lan` but later direct connections failed; runtime validation remains pending until the printer is reachable and the configuration is deployed.

To roll back configuration, remove the three host imports and the dedicated module, then deploy normally. NixOS `ensurePrinters` does not delete previously created queues when removed; explicitly remove the `brother` queue separately if desired. Documents and other printers are not managed by this module.

Sources: [Brother family specifications and network protocols](https://support.brother.com/g/b/spec.aspx?c=as_ot&lang=en&prod=dcp1610w_eu_as), [brlaser 6.2.8](https://github.com/Owl-Maintain/brlaser/tree/v6.2.8), [Brother macOS network scanning guidance](https://support.brother.com/g/b/faqend.aspx?c=eu_ot&faqid=faq00002637_011&lang=en&prod=dcp1610w_eu_as).
