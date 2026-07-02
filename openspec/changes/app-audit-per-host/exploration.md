# Exploration: App Audit Per Host

## Goal

Catalogue every application installed across the three Linux hosts (`rog`,
`thinkcentre`, `t14`) and produce a per-host inventory that makes the
duplication, suite-bias, and per-host drift visible at a glance.

## Current State

The repo composes system-level packages via a profile chain:

```
modules/profiles/base.nix   → modules/base/packages.nix (top-level)
modules/profiles/desktop.nix → base.nix + fonts/i18n/kmscon/keyring
modules/profiles/server.nix  → desktop.nix + xrdp + wol + docker
```

`modules/base/packages.nix` (imported transitively by rog/thinkcentre via
`profiles/server.nix` and **directly** by t14 via
`hosts/t14/default.nix:28`) flattens six profiles into one
`environment.systemPackages`:

| Profile           | Defined at                                  | Drives            |
|-------------------|---------------------------------------------|-------------------|
| `base.nix`        | `modules/base/profiles/base.nix`            | CLI + desktop apps|
| Suite: `mate.nix` | `modules/base/profiles/mate.nix:6-20`       | MATE DE (rog/tc)  |
| Suite: `gnome.nix`| `modules/base/profiles/gnome.nix:6-11`      | GNOME bits (t14)  |
| `dev.nix`         | `modules/base/profiles/dev.nix:4-37`        | Toolchains        |
| `media.nix`       | `modules/base/profiles/media.nix:4-20`      | Audio/video       |
| `virt.nix`        | `modules/base/profiles/virt.nix:4-19`       | VMs + Docker      |
| `browsers.nix`    | `modules/base/profiles/browsers.nix:4-10`   | Web browsers      |

### Per-host configuration

| Host         | Profile chain                          | `my.desktop.suite` | Extra systemPkgs                  | HM modules                                                |
|--------------|----------------------------------------|--------------------|-----------------------------------|-----------------------------------------------------------|
| `rog`        | `profiles/server.nix` → ALL profiles   | `mate`             | xrdp mate-polkit/xset/zenity, keyring pkgs, libvirt, nvidia, asus-fan-control, pipewire-xrdp, ~20 docker services | `shared-modules.nix` + remote-desktop + picom + mate-rog-autostart + conky-rog + openfang |
| `thinkcentre`| `profiles/server.nix` → ALL profiles   | `mate`             | xrdp mate-polkit/xset/zenity, keyring pkgs | `shared-modules.nix` + remote-desktop + picom + conky-thinkcentre |
| `t14`        | `modules/base/packages.nix` directly   | `gnome`            | omarchy-nix `modules/packages.nix` (nautilus, evince, loupe, sushi, ffmpegthumbnailer, brave, walker, elephant, …) | omarchy-nix `homeManagerModules.default` + selective shared (base, shell, git, gh, ssh, tmux, neovim, opencode, sops) + remote-desktop + ghostty + kitty + hyprland fragments |

The home-manager canonical list is `home-linux/shared-modules.nix` (single
source of truth — see AGENTS.md rule 9). t14 deliberately **excludes**
`rofi.nix`, `mate.nix`, `chrome-apps.nix`, `theme.nix`, and `picom.nix` from
its HM import set because omarchy-nix owns rofi→walker, theme, compositor
and webapps.

## Affected Areas (the files that contribute to the inventory)

- `modules/base/profiles/{base,mate,gnome,dev,media,virt,browsers}.nix` — system packages
- `modules/hardware/keyring.nix:5-8` — `gnome-keyring`, `libsecret`
- `modules/features/services/xrdp.nix:136-140` — `mate-polkit`, `xset`, `zenity`
- `hosts/{rog,thinkcentre,t14}/default.nix` — host-level options
- `home-linux/shared-modules.nix` — canonical HM module list
- `home-linux/{base,shell,theme,tmux,neovim,mate,rofi,git,gh,ghostty,kitty,alacritty,chrome-apps,ssh,picom,remote-desktop,conky-rog,conky-thinkcentre,mate-rog-autostart,openfang}.nix` — per-feature HM modules
- `hosts/{rog,thinkcentre}/home/modules.nix` — host HM module list
- `hosts/t14/home/{omarchy.nix,default.nix,hypr/*.nix,mouse-wiggle.nix}` — t14 HM
- `pkgs/{asus-fan-control,pipewire-module-xrdp,engram,gentle-ai,opencode,openfang,nixos-scripts}/default.nix` — custom package derivations
- `overlays/linux.nix:7-29` — wires overlays into `pkgs`
- `flake.nix:19-23, 204-217, 233-276` — `omarchy-nix` flake input + per-host `extraModules` / `homeConfigurations`
- `flake.lock:8-18` — `omarchy-nix` pinned to `glats/omarchy-nix` `662b0dcbc9662a00558f12330dd43795d368bb06` (github source, not a path)
- omarchy-nix upstream source (resolved via `nix flake archive` against the pinned rev):
  - `modules/packages.nix` — systemPackages
  - `modules/nixos/system.nix:131-134` — adds `[ walker, elephant-with-providers ]`
  - `modules/home-manager/default.nix` — HM entry; imports `alacritty, ghostty, kitty, btop, direnv, git, mako, starship, vscode, waybar, walker, zoxide, zsh, chromium, brave, xdph, hypridle, hyprland, hyprlock, hyprpaper, hyprsunset, swayosd, swaybg, imv, evince, zellij, tmux, theme-generator, omarchy-post-boot` etc.

## Comprehensive Package Inventory

Column legend:
- ✅ installed
- ❌ not installed
- ⚠️ installed differently (e.g. only as PATH helper, autostart desktop file, or user-level wrapper)
- ⓜ MATE-native, ⓖ GNOME-native, Ⓝ neutral

| # | Package | Category | Defined in (file:line) | ⓜ/ⓖ/Ⓝ | rog | thinkcentre | t14 | Notes |
|---|---------|----------|------------------------|---------|-----|-------------|-----|-------|
| 1 | `fzf` | shell-util | `modules/base/profiles/base.nix:11` | Ⓝ | ✅ | ✅ | ✅ | also in omarchy `modules/packages.nix:53` (dup) |
| 2 | `bat` | shell-util | `modules/base/profiles/base.nix:12` | Ⓝ | ✅ | ✅ | ❌ | |
| 3 | `delta` | shell-util | `modules/base/profiles/base.nix:13` | Ⓝ | ✅ | ✅ | ❌ | used as `core.pager` in `home-linux/git.nix:10` |
| 4 | `curl` | shell-util | `modules/base/profiles/base.nix:14` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:59`) |
| 5 | `wget` | shell-util | `modules/base/profiles/base.nix:15` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:61`) |
| 6 | `aria2` | shell-util | `modules/base/profiles/base.nix:16` | Ⓝ | ✅ | ✅ | ❌ | |
| 7 | `zip` | shell-util | `modules/base/profiles/base.nix:17` | Ⓝ | ✅ | ✅ | ❌ | |
| 8 | `unzip` | shell-util | `modules/base/profiles/base.nix:18` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:60`) |
| 9 | `p7zip` | shell-util | `modules/base/profiles/base.nix:19` | Ⓝ | ✅ | ✅ | ❌ | |
| 10 | `rar` | shell-util | `modules/base/profiles/base.nix:20` | Ⓝ | ✅ | ✅ | ❌ | |
| 11 | `unrar` | shell-util | `modules/base/profiles/base.nix:21` | Ⓝ | ✅ | ✅ | ❌ | |
| 12 | `xz` | shell-util | `modules/base/profiles/base.nix:22` | Ⓝ | ✅ | ✅ | ❌ | |
| 13 | `file` | shell-util | `modules/base/profiles/base.nix:23` | Ⓝ | ✅ | ✅ | ❌ | |
| 14 | `tree` | shell-util | `modules/base/profiles/base.nix:24` | Ⓝ | ✅ | ✅ | ❌ | |
| 15 | `ncdu` | shell-util | `modules/base/profiles/base.nix:25` | Ⓝ | ✅ | ✅ | ❌ | |
| 16 | `duf` | shell-util | `modules/base/profiles/base.nix:26` | Ⓝ | ✅ | ✅ | ❌ | |
| 17 | `imagemagick` | image-util | `modules/base/profiles/base.nix:27` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy uses it in elephant PATH: `system.nix:38`); also in `home-linux/neovim.nix:13` |
| 18 | `fastfetch` | system-monitor | `modules/base/profiles/base.nix:30` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:69`) |
| 19 | `htop` | system-monitor | `modules/base/profiles/base.nix:31` | Ⓝ | ✅ | ✅ | ❌ | |
| 20 | `btop` | system-monitor | `modules/base/profiles/base.nix:32` | Ⓝ | ✅ | ✅ | ✅ | rog/tc via base; t14 via omarchy `modules/home-manager/btop.nix` + `modules/packages.nix:67` |
| 21 | `iotop` | system-monitor | `modules/base/profiles/base.nix:33` | Ⓝ | ✅ | ✅ | ❌ | |
| 22 | `iftop` | system-monitor | `modules/base/profiles/base.nix:34` | Ⓝ | ✅ | ✅ | ❌ | |
| 23 | `nethogs` | system-monitor | `modules/base/profiles/base.nix:35` | Ⓝ | ✅ | ✅ | ❌ | |
| 24 | `lsof` | system-util | `modules/base/profiles/base.nix:36` | Ⓝ | ✅ | ✅ | ❌ | |
| 25 | `sysstat` | system-util | `modules/base/profiles/base.nix:37` | Ⓝ | ✅ | ✅ | ❌ | |
| 26 | `lshw` | system-util | `modules/base/profiles/base.nix:38` | Ⓝ | ✅ | ✅ | ❌ | |
| 27 | `pciutils` | system-util | `modules/base/profiles/base.nix:39` | Ⓝ | ✅ | ✅ | ❌ | |
| 28 | `usbutils` | system-util | `modules/base/profiles/base.nix:40` | Ⓝ | ✅ | ✅ | ❌ | |
| 29 | `util-linux` | system-util | `modules/base/profiles/base.nix:41` | Ⓝ | ✅ | ✅ | ❌ | |
| 30 | `coreutils` | shell-util | `modules/base/profiles/base.nix:42` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy uses it in PATH wrappers) |
| 31 | `findutils` | shell-util | `modules/base/profiles/base.nix:43` | Ⓝ | ✅ | ✅ | ❌ | |
| 32 | `binutils` | dev-tool | `modules/base/profiles/base.nix:44` | Ⓝ | ✅ | ✅ | ❌ | |
| 33 | `lsd` | shell-util | `modules/base/profiles/base.nix:45` | Ⓝ | ✅ | ✅ | ❌ | not installed on t14 (omarchy uses `eza` instead) |
| 34 | `cmatrix` | other | `modules/base/profiles/base.nix:46` | Ⓝ | ✅ | ✅ | ❌ | |
| 35 | `scrot` | screenshot | `modules/base/profiles/base.nix:47` | Ⓝ | ✅ | ✅ | ❌ | replaced by `flameshot` autostart (`home-linux/mate.nix:278-292`) and `hyprshot` on t14 |
| 36 | `systemctl-tui` | system-util | `modules/base/profiles/base.nix:48` | Ⓝ | ✅ | ✅ | ❌ | |
| 37 | `xclip` | shell-util | `modules/base/profiles/base.nix:49` | Ⓝ | ✅ | ✅ | ❌ | t14 uses `wl-clipboard` (omarchy `system.nix:36`) |
| 38 | `xxd` | shell-util | `modules/base/profiles/base.nix:50` | Ⓝ | ✅ | ✅ | ❌ | |
| 39 | `iproute2` | networking | `modules/base/profiles/base.nix:53` | Ⓝ | ✅ | ✅ | ❌ | |
| 40 | `iputils` | networking | `modules/base/profiles/base.nix:54` | Ⓝ | ✅ | ✅ | ❌ | |
| 41 | `dnsutils` | networking | `modules/base/profiles/base.nix:55` | Ⓝ | ✅ | ✅ | ❌ | |
| 42 | `nettools` | networking | `modules/base/profiles/base.nix:56` | Ⓝ | ✅ | ✅ | ❌ | |
| 43 | `nmap` | networking | `modules/base/profiles/base.nix:57` | Ⓝ | ✅ | ✅ | ❌ | |
| 44 | `wakeonlan` | networking | `modules/base/profiles/base.nix:58` | Ⓝ | ✅ | ✅ | ❌ | |
| 45 | `ethtool` | networking | `modules/base/profiles/base.nix:59` | Ⓝ | ✅ | ✅ | ❌ | |
| 46 | `tcpdump` | networking | `modules/base/profiles/base.nix:60` | Ⓝ | ✅ | ✅ | ❌ | |
| 47 | `sshfs` | networking | `modules/base/profiles/base.nix:61` | Ⓝ | ✅ | ✅ | ❌ | |
| 48 | `avahi` | networking | `modules/base/profiles/base.nix:62` | Ⓝ | ✅ | ✅ | ✅ | dup on t14: omarchy `system.nix:182-193` enables `services.avahi` |
| 49 | `thttpd` | networking | `modules/base/profiles/base.nix:63` | Ⓝ | ✅ | ✅ | ❌ | |
| 50 | `sqlite` | dev-tool | `modules/base/profiles/base.nix:64` | Ⓝ | ✅ | ✅ | ❌ | |
| 51 | `git` (nixpkgs) | dev-tool | `modules/base/profiles/base.nix:67` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:11`); HM also enables `programs.git` in `home-linux/git.nix` and `omarchy/home-manager/git.nix` |
| 52 | `nil` | dev-tool | `modules/base/profiles/base.nix:68` | Ⓝ | ✅ | ✅ | ❌ | |
| 53 | `nix-output-monitor` | dev-tool | `modules/base/profiles/base.nix:69` | Ⓝ | ✅ | ✅ | ❌ | |
| 54 | `nixpkgs-fmt` | dev-tool | `modules/base/profiles/base.nix:70` | Ⓝ | ✅ | ✅ | ❌ | (note: replaced by `nixfmt` in `flake.nix:289-290`) |
| 55 | `statix` | dev-tool | `modules/base/profiles/base.nix:71` | Ⓝ | ✅ | ✅ | ❌ | |
| 56 | `deadnix` | dev-tool | `modules/base/profiles/base.nix:72` | Ⓝ | ✅ | ✅ | ❌ | |
| 57 | `nix-search-cli` | dev-tool | `modules/base/profiles/base.nix:73` | Ⓝ | ✅ | ✅ | ❌ | |
| 58 | `lazygit` | dev-tool | `modules/base/profiles/base.nix:74` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:65`) |
| 59 | `lazydocker` | dev-tool | `modules/base/profiles/base.nix:75` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:66`) |
| 60 | `home-manager` | dev-tool | `modules/base/profiles/base.nix:76` | Ⓝ | ✅ | ✅ | ❌ | |
| 61 | `jq` | shell-util | `modules/base/profiles/base.nix:79` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:58`) |
| 62 | `yq` | shell-util | `modules/base/profiles/base.nix:80` | Ⓝ | ✅ | ✅ | ❌ | |
| 63 | `libsecret` | keyring | `modules/base/profiles/base.nix:81` | Ⓝ | ✅ | ✅ | ✅ | **Triple-declared:** also `modules/hardware/keyring.nix:7` + omarchy `modules/packages.nix:134`; HM `home-linux/remote-desktop.nix:218` adds to `home.packages` |
| 64 | `google-cloud-sdk` | dev-tool | `modules/base/profiles/base.nix:82` | Ⓝ | ✅ | ✅ | ❌ | |
| 65 | `dex` | dev-tool | `modules/base/profiles/base.nix:83` | Ⓝ | ✅ | ✅ | ❌ | |
| 66 | `ghostty` (system) | terminal | `modules/base/profiles/base.nix:86` | Ⓝ | ✅ | ✅ | ✅ | also in omarchy `modules/packages.nix:32`; HM `programs.ghostty` enabled in `home-linux/ghostty.nix` (rog/tc via shared, t14 via own) |
| 67 | `windsurf` | dev-tool | `modules/base/profiles/base.nix:87` | Ⓝ | ✅ | ✅ | ❌ | |
| 68 | `flatpak` | other | `modules/base/profiles/base.nix:88` | Ⓝ | ✅ | ✅ | ❌ | |
| 69 | `meld` | dev-tool | `modules/base/profiles/base.nix:89` | Ⓝ | ✅ | ✅ | ❌ | |
| 70 | `xdg-user-dirs` | other | `modules/base/profiles/base.nix:90` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `home-manager/default.nix:218-227` enables `xdg.userDirs`) |
| 71 | `hicolor-icon-theme` | theme | `modules/base/profiles/base.nix:91` | Ⓝ | ✅ | ✅ | ❌ | |
| 72 | `papirus-icon-theme` | theme | `modules/base/profiles/base.nix:92` | Ⓝ | ✅ | ✅ | ✅ | t14 wired via `hosts/t14/home/omarchy.nix:160-163` (omarchy HM doesn't set iconTheme) |
| 73 | `gnome-themes-extra` | theme | `modules/base/profiles/base.nix:93` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:25`, used as gtk theme `package` in `home-manager/default.nix:240-243`) |
| 74 | `gtk-engine-murrine` | theme | `modules/base/profiles/base.nix:94` | Ⓝ | ✅ | ✅ | ❌ | |
| 75 | `adwaita-icon-theme` | theme | `modules/base/profiles/base.nix:95` | Ⓝ | ✅ | ✅ | ❌ | |
| 76 | `flameshot` | screenshot | `modules/base/profiles/base.nix:96` | Ⓝ | ✅ | ✅ | ❌ | Autostart via `home-linux/mate.nix:278-292`; t14 uses omarchy's `hyprshot` instead |
| 77 | `copyq` | clipboard | `modules/base/profiles/base.nix:97` | Ⓝ | ✅ | ✅ | ❌ | Autostart via `home-linux/mate.nix:265-275`; t14 uses omarchy's `clipse` (`modules/packages.nix:27`) |
| 78 | `gpaste` | clipboard | `modules/base/profiles/base.nix:98` | Ⓝ | ✅ | ✅ | ❌ | not autostarted (copyq is) |
| 79 | `conky` | system-monitor | `modules/base/profiles/base.nix:99` | Ⓝ | ✅ | ✅ | ❌ | rog/tc only; t14 uses waybar via omarchy HM |
| 80 | `networkmanagerapplet` | networking | `modules/base/profiles/base.nix:100` | Ⓝ | ✅ | ✅ | ✅ | nm-applet; on t14 omarchy uses `networkmanager` with iwd backend per `system.nix:217-229` |
| 81 | `gparted` | other | `modules/base/profiles/base.nix:101` | Ⓝ | ✅ | ✅ | ❌ | |
| 82 | `hexchat` | other | `modules/base/profiles/base.nix:102` | Ⓝ | ✅ (autostart) | ✅ | ❌ | rog has autostart desktop via `home-linux/mate-rog-autostart.nix:1-20` |
| 83 | `popsicle` | other | `modules/base/profiles/base.nix:103` | Ⓝ | ✅ | ✅ | ❌ | |
| 84 | `hypridle` | other | `modules/base/profiles/base.nix:104` | Ⓝ | ✅ | ✅ | ✅ | t14 fully wired via omarchy HM `modules/home-manager/hypridle.nix` + `hosts/t14/home/omarchy.nix:126-149` |
| 85 | `remmina` | remote-desktop | `modules/base/profiles/base.nix:105` | Ⓝ | ✅ | ✅ | ✅ | HM `home-linux/remote-desktop.nix:217` adds to `home.packages`; profiles at `.local/share/remmina/{rdp-rog,rdp-oneplus5,rdp-thinkcentre,vnc-t14,vnc-mact2}.remmina` |
| 86 | `asus-fan-control` | hardware | `modules/base/profiles/base.nix:108` | Ⓝ | ✅ | ❌ | ❌ | rog-only (`pkgs/asus-fan-control/default.nix`); service `afc.service` |
| 87 | `pipewire-module-xrdp` | audio | `modules/base/profiles/base.nix:109` | Ⓝ | ✅ | ❌ | ❌ | rog-only (`pkgs/pipewire-module-xrdp/default.nix`); t14 uses omarchy's standard pipewire |
| 88 | `atril` | pdf-viewer | `modules/base/profiles/mate.nix:8` | ⓜ | ✅ | ✅ | ❌ | MATE; t14 uses `evince` (omarchy `modules/home-manager/evince.nix`) |
| 89 | `caja` | file-manager | `modules/base/profiles/mate.nix:9` | ⓜ | ✅ | ✅ | ❌ | MATE; t14 uses `nautilus` (omarchy `modules/packages.nix:17`) |
| 90 | `engrampa` | other | `modules/base/profiles/mate.nix:10` | ⓜ | ✅ | ✅ | ❌ | MATE archive manager |
| 91 | `eom` | image-viewer | `modules/base/profiles/mate.nix:11` | ⓜ | ✅ | ✅ | ❌ | MATE; t14 uses `loupe` (omarchy `modules/packages.nix:84`) |
| 92 | `marco` | compositor | `modules/base/profiles/mate.nix:12` | ⓜ | ✅ | ✅ | ❌ | MATE wm; t14 uses `hyprland` (omarchy) |
| 93 | `pluma` | text-editor | `modules/base/profiles/mate.nix:13` | ⓜ | ✅ | ✅ | ❌ | MATE editor |
| 94 | `mate-panel` | other | `modules/base/profiles/mate.nix:14` | ⓜ | ✅ | ✅ | ❌ | MATE panel |
| 95 | `mate-sensors-applet` | system-monitor | `modules/base/profiles/mate.nix:15` | ⓜ | ✅ | ✅ | ❌ | |
| 96 | `mate-user-share` | other | `modules/base/profiles/mate.nix:16` | ⓜ | ✅ | ✅ | ❌ | |
| 97 | `materia-theme` | theme | `modules/base/profiles/mate.nix:19` | ⓜ | ✅ | ✅ | ❌ | MATE; t14 omarchy uses `Adwaita-dark` |
| 98 | `gnome-system-monitor` | system-monitor | `modules/base/profiles/gnome.nix:10` | ⓖ | ❌ | ❌ | ✅ | t14 only (suite = "gnome") |
| 99 | `gcc` | dev-tool | `modules/base/profiles/dev.nix:8` | Ⓝ | ✅ | ✅ | ✅ | |
| 100 | `gnumake` | dev-tool | `modules/base/profiles/dev.nix:9` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:62`) |
| 101 | `cmake` | dev-tool | `modules/base/profiles/dev.nix:10` | Ⓝ | ✅ | ✅ | ✅ | |
| 102 | `meson` | dev-tool | `modules/base/profiles/dev.nix:11` | Ⓝ | ✅ | ✅ | ✅ | |
| 103 | `ninja` | dev-tool | `modules/base/profiles/dev.nix:12` | Ⓝ | ✅ | ✅ | ✅ | |
| 104 | `autoconf` | dev-tool | `modules/base/profiles/dev.nix:13` | Ⓝ | ✅ | ✅ | ✅ | |
| 105 | `automake` | dev-tool | `modules/base/profiles/dev.nix:14` | Ⓝ | ✅ | ✅ | ✅ | |
| 106 | `libtool` | dev-tool | `modules/base/profiles/dev.nix:15` | Ⓝ | ✅ | ✅ | ✅ | |
| 107 | `pkg-config` | dev-tool | `modules/base/profiles/dev.nix:16` | Ⓝ | ✅ | ✅ | ✅ | |
| 108 | `go` | dev-tool | `modules/base/profiles/dev.nix:19` | Ⓝ | ✅ | ✅ | ✅ | |
| 109 | `nodejs` | dev-tool | `modules/base/profiles/dev.nix:20` | Ⓝ | ✅ | ✅ | ✅ | dup (also `home-linux/neovim.nix:10`) |
| 110 | `nodejs_22` | dev-tool | `modules/base/profiles/dev.nix:21` | Ⓝ | ✅ | ✅ | ✅ | |
| 111 | `bun` | dev-tool | `modules/base/profiles/dev.nix:22` | Ⓝ | ✅ | ✅ | ✅ | |
| 112 | `neovim` (system) | text-editor | `modules/base/profiles/dev.nix:25` | Ⓝ | ✅ | ✅ | ✅ | HM `programs.neovim` enabled in `home-linux/neovim.nix:21` (rog/tc with custom LazyVim) and omarchy `home-manager/default.nix:259-263` (t14 with minimal config) |
| 113 | `codex` | dev-tool | `modules/base/profiles/dev.nix:28` | Ⓝ | ✅ | ✅ | ✅ | |
| 114 | `opencode` (system) | dev-tool | `modules/base/profiles/dev.nix:29` | Ⓝ | ✅ | ✅ | ✅ | custom derivation `pkgs/opencode/default.nix` (v1.17.11) |
| 115 | `openfang` (system) | dev-tool | `modules/base/profiles/dev.nix:30` | Ⓝ | ✅ | ✅ | ✅ | custom derivation `pkgs/openfang/default.nix` (v0.6.4); autostart via `home-linux/openfang.nix:130-150` only on rog |
| 116 | `godot_4-mono` | dev-tool | `modules/base/profiles/dev.nix:33` | Ⓝ | ✅ | ✅ | ✅ | |
| 117 | `dotnet-sdk_8` | dev-tool | `modules/base/profiles/dev.nix:36` | Ⓝ | ✅ | ✅ | ✅ | exposed as `DOTNET_ROOT` in `home-linux/shell.nix:59` |
| 118 | `mpv` | media | `modules/base/profiles/media.nix:7` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:82`) |
| 119 | `wiremix` | media | `modules/base/profiles/media.nix:8` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:44`) |
| 120 | `ffmpeg` | media | `modules/base/profiles/media.nix:9` | Ⓝ | ✅ | ✅ | ✅ | dup (omarchy `modules/packages.nix:16`) |
| 121 | `intel-vaapi-driver` | media | `modules/base/profiles/media.nix:12` | Ⓝ | ✅ | ✅ | ❌ | |
| 122 | `libva-vdpau-driver` | media | `modules/base/profiles/media.nix:13` | Ⓝ | ✅ | ✅ | ❌ | |
| 123 | `libva-utils` | media | `modules/base/profiles/media.nix:14` | Ⓝ | ✅ | ✅ | ❌ | |
| 124 | `intel-gpu-tools` | media | `modules/base/profiles/media.nix:15` | Ⓝ | ✅ | ✅ | ❌ | |
| 125 | `gst-plugins-base` | media | `modules/base/profiles/media.nix:18` | Ⓝ | ✅ | ✅ | ❌ | |
| 126 | `gst-plugins-good` | media | `modules/base/profiles/media.nix:19` | Ⓝ | ✅ | ✅ | ❌ | |
| 127 | `qemu_kvm` | vm | `modules/base/profiles/virt.nix:7` | Ⓝ | ✅ | ✅ | ❌ | rog also imports `modules/virtualisation/libvirt.nix` |
| 128 | `virt-manager` | vm | `modules/base/profiles/virt.nix:8` | Ⓝ | ✅ | ✅ | ❌ | |
| 129 | `virt-viewer` | vm | `modules/base/profiles/virt.nix:9` | Ⓝ | ✅ | ✅ | ❌ | |
| 130 | `spice-gtk` | vm | `modules/base/profiles/virt.nix:10` | Ⓝ | ✅ | ✅ | ❌ | |
| 131 | `dnsmasq` | vm | `modules/base/profiles/virt.nix:13` | Ⓝ | ✅ | ✅ | ❌ | |
| 132 | `bridge-utils` | vm | `modules/base/profiles/virt.nix:14` | Ⓝ | ✅ | ✅ | ❌ | |
| 133 | `vde2` | vm | `modules/base/profiles/virt.nix:15` | Ⓝ | ✅ | ✅ | ❌ | |
| 134 | `docker` | vm | `modules/base/profiles/virt.nix:18` | Ⓝ | ✅ | ✅ | ✅ | t14 explicitly imports `modules/virtualisation/docker.nix:58`; also `services.xserver` via omarchy on t14 |
| 135 | `google-chrome` | browser | `modules/base/profiles/browsers.nix:6` | Ⓝ | ✅ | ✅ | ❌ | referenced as hard path `chromePath` in `home-linux/chrome-apps.nix:6` |
| 136 | `microsoft-edge` | browser | `modules/base/profiles/browsers.nix:7` | Ⓝ | ✅ | ✅ | ❌ | |
| 137 | `chromium` | browser | `modules/base/profiles/browsers.nix:8` | Ⓝ | ✅ | ✅ | ✅ (fallback) | t14 omarchy: `brave` if `omarchy.browser == "brave"` (set), else `chromium` (`omarchy/modules/packages.nix:79`) |
| 138 | `brave` | browser | `modules/base/profiles/browsers.nix:9` | Ⓝ | ✅ | ✅ | ✅ (active) | active on t14 (set via `omarchy.browser = "brave"` in `hosts/t14/default.nix:143`) |
| 139 | `gnome-keyring` | keyring | `modules/hardware/keyring.nix:6` | ⓖ | ✅ | ✅ | ✅ | t14: also from omarchy `modules/packages.nix:133` and `system.nix:206-207` |
| 140 | `mate-polkit` | other | `modules/features/services/xrdp.nix:137` | ⓜ | ✅ | ✅ | ❌ | rog/tc only (xrdp-only helper) |
| 141 | `xset` | other | `modules/features/services/xrdp.nix:138` | Ⓝ | ✅ | ✅ | ❌ | used in xrdp preamble to disable DPMS |
| 142 | `zenity` | other | `modules/features/services/xrdp.nix:139` | Ⓝ | ✅ | ✅ | ❌ | |
| — | **OMARCHY-NIX SYSTEM PACKAGES (t14 only)** |||||||
| 143 | `git` | dev-tool | `omarchy-nix modules/packages.nix:11` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #51 |
| 144 | `vim` | text-editor | `omarchy-nix modules/packages.nix:12` | Ⓝ | ❌ | ❌ | ✅ | t14 only via omarchy |
| 145 | `libnotify` | dev-tool | `omarchy-nix modules/packages.nix:13` | Ⓝ | ❌ | ❌ | ✅ | |
| 146 | `pavucontrol` | media | `omarchy-nix modules/packages.nix:14` | Ⓝ | ❌ | ❌ | ✅ | t14 audio GUI |
| 147 | `brightnessctl` | shell-util | `omarchy-nix modules/packages.nix:15` | Ⓝ | ❌ | ❌ | ✅ | |
| 148 | `ffmpeg` | media | `omarchy-nix modules/packages.nix:16` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #120 |
| 149 | `nautilus` | file-manager | `omarchy-nix modules/packages.nix:17` | ⓖ | ❌ | ❌ | ✅ | replaces `caja` on t14 |
| 150 | `hyprshot` | screenshot | `omarchy-nix modules/packages.nix:18` | Ⓝ | ❌ | ❌ | ✅ | Wayland screenshot |
| 151 | `hyprpicker` | other | `omarchy-nix modules/packages.nix:19` | Ⓝ | ❌ | ❌ | ✅ | Wayland color picker |
| 152 | `hyprsunset` | other | `omarchy-nix modules/packages.nix:20` | Ⓝ | ❌ | ❌ | ✅ | blue-light filter (gammastep alternative) |
| 153 | `alejandra` | dev-tool | `omarchy-nix modules/packages.nix:21` | Ⓝ | ❌ | ❌ | ✅ | Nix formatter (NOTE: in this repo we use `nixfmt`, see `flake.nix:289`) |
| 154 | `pamixer` | media | `omarchy-nix modules/packages.nix:22` | Ⓝ | ❌ | ❌ | ✅ | |
| 155 | `playerctl` | media | `omarchy-nix modules/packages.nix:23` | Ⓝ | ❌ | ❌ | ✅ | |
| 156 | `bibata-cursors` | theme | `omarchy-nix modules/packages.nix:24` | Ⓝ | ❌ | ❌ | ✅ | cursor theme (omarchy `home-manager/default.nix:244-247`) |
| 157 | `gnome-themes-extra` | theme | `omarchy-nix modules/packages.nix:25` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #73 |
| 158 | `blueman` | networking | `omarchy-nix modules/packages.nix:26` | Ⓝ | ❌ | ❌ | ✅ | disabled in autostart by `omarchy home-manager/default.nix:120-123` (uses bluetui instead) |
| 159 | `clipse` | clipboard | `omarchy-nix modules/packages.nix:27` | Ⓝ | ❌ | ❌ | ✅ | t14 clipboard (replaces rog/tc `copyq`) |
| 160 | `xdg-utils` | shell-util | `omarchy-nix modules/packages.nix:28` | Ⓝ | ❌ | ❌ | ✅ | |
| 161 | `xdg-terminal-exec` | shell-util | `omarchy-nix modules/packages.nix:29` | Ⓝ | ❌ | ❌ | ✅ | |
| 162 | `ghostty` (system, omarchy) | terminal | `omarchy-nix modules/packages.nix:32` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #66 |
| 163 | `alacritty` (system, omarchy) | terminal | `omarchy-nix modules/packages.nix:33` | Ⓝ | ❌ | ❌ | ✅ | HM `programs.alacritty` also in shared `home-linux/alacritty.nix` |
| 164 | `kitty` (system, omarchy) | terminal | `omarchy-nix modules/packages.nix:34` | Ⓝ | ❌ | ❌ | ✅ | HM `programs.kitty` in shared `home-linux/kitty.nix` and omarchy `modules/home-manager/kitty.nix` |
| 165 | `satty` | screenshot | `omarchy-nix modules/packages.nix:37` | Ⓝ | ❌ | ❌ | ✅ | Wayland screenshot annotation |
| 166 | `wf-recorder` | media | `omarchy-nix modules/packages.nix:38` | Ⓝ | ❌ | ❌ | ✅ | Wayland screen recorder |
| 167 | `gpu-screen-recorder` | media | `omarchy-nix modules/packages.nix:39` | Ⓝ | ❌ | ❌ | ✅ | |
| 168 | `slurp` | other | `omarchy-nix modules/packages.nix:40` | Ⓝ | ❌ | ❌ | ✅ | Wayland region selector |
| 169 | `hyprland-preview-share-picker` | other | `omarchy-nix modules/packages.nix:41` | Ⓝ | ❌ | ❌ | ✅ | custom package (`omarchy-nix/packages/hyprland-preview-share-picker.nix`) |
| 170 | `wiremix` (omarchy) | media | `omarchy-nix modules/packages.nix:44` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #119 |
| 171 | `swayosd` | other | `omarchy-nix modules/packages.nix:47` | Ⓝ | ❌ | ❌ | ✅ | OSD volume/brightness |
| 172 | `swaybg` | theme | `omarchy-nix modules/packages.nix:50` | Ⓝ | ❌ | ❌ | ✅ | wallpaper daemon |
| 173 | `fzf` (omarchy) | shell-util | `omarchy-nix modules/packages.nix:53` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #1 |
| 174 | `zoxide` | shell-util | `omarchy-nix modules/packages.nix:54` | Ⓝ | ❌ | ❌ | ✅ | HM `programs.zoxide` (`omarchy/home-manager/zoxide.nix`) |
| 175 | `ripgrep` | shell-util | `omarchy-nix modules/packages.nix:55` | Ⓝ | ❌ | ❌ | ✅ | dup (also `home-linux/neovim.nix:7`) |
| 176 | `eza` | shell-util | `omarchy-nix modules/packages.nix:56` | Ⓝ | ❌ | ❌ | ✅ | replaces `lsd` (omarchy uses eza; base has lsd but not eza) |
| 177 | `fd` | shell-util | `omarchy-nix modules/packages.nix:57` | Ⓝ | ❌ | ❌ | ✅ | dup (also `home-linux/neovim.nix:8`) |
| 178 | `jq` (omarchy) | shell-util | `omarchy-nix modules/packages.nix:58` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #61 |
| 179 | `curl` (omarchy) | shell-util | `omarchy-nix modules/packages.nix:59` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #4 |
| 180 | `unzip` (omarchy) | shell-util | `omarchy-nix modules/packages.nix:60` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #8 |
| 181 | `wget` (omarchy) | shell-util | `omarchy-nix modules/packages.nix:61` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #5 |
| 182 | `gnumake` (omarchy) | dev-tool | `omarchy-nix modules/packages.nix:62` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #100 |
| 183 | `lazygit` (omarchy) | dev-tool | `omarchy-nix modules/packages.nix:65` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #58 |
| 184 | `lazydocker` (omarchy) | dev-tool | `omarchy-nix modules/packages.nix:66` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #59 |
| 185 | `btop` (omarchy) | system-monitor | `omarchy-nix modules/packages.nix:67` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #20 |
| 186 | `powertop` | system-monitor | `omarchy-nix modules/packages.nix:68` | Ⓝ | ❌ | ❌ | ✅ | |
| 187 | `fastfetch` (omarchy) | system-monitor | `omarchy-nix modules/packages.nix:69` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #18 |
| 188 | `gum` | shell-util | `omarchy-nix modules/packages.nix:70` | Ⓝ | ❌ | ❌ | ✅ | TUI script helpers |
| 189 | `bluetui` | networking | `omarchy-nix modules/packages.nix:71` | Ⓝ | ❌ | ❌ | ✅ | bluetooth TUI (replaces blueman tray) |
| 190 | `impala` | networking | `omarchy-nix modules/packages.nix:72` | Ⓝ | ❌ | ❌ | ✅ | WiFi TUI (iwd) |
| 191 | `inxi` | system-monitor | `omarchy-nix modules/packages.nix:73` | Ⓝ | ❌ | ❌ | ✅ | |
| 192 | `terminaltexteffects` | other | `omarchy-nix modules/packages.nix:76` | Ⓝ | ❌ | ❌ | ✅ | custom omarchy screensaver (`omarchy-nix/packages/terminaltexteffects.nix`) |
| 193 | `brave` (omarchy) | browser | `omarchy-nix modules/packages.nix:79` | Ⓝ | ❌ | ❌ | ✅ | active on t14 |
| 194 | `obsidian` | notes | `omarchy-nix modules/packages.nix:80` | Ⓝ | ❌ | ❌ | ✅ | |
| 195 | `vlc` | media | `omarchy-nix modules/packages.nix:81` | Ⓝ | ❌ | ❌ | ✅ | |
| 196 | `mpv` (omarchy) | media | `omarchy-nix modules/packages.nix:82` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #118 |
| 197 | `gnome-calculator` | other | `omarchy-nix modules/packages.nix:83` | ⓖ | ❌ | ❌ | ✅ | |
| 198 | `loupe` | image-viewer | `omarchy-nix modules/packages.nix:84` | ⓖ | ❌ | ❌ | ✅ | replaces `eom` on t14 |
| 199 | `krita` | other | `omarchy-nix modules/packages.nix:85` | Ⓝ | ❌ | ❌ | ✅ | drawing/painting |
| 200 | `pinta` | other | `omarchy-nix modules/packages.nix:86` | Ⓝ | ❌ | ❌ | ✅ | lightweight image editor |
| 201 | `xournalpp` | other | `omarchy-nix modules/packages.nix:87` | Ⓝ | ❌ | ❌ | ✅ | PDF annotation |
| 202 | `localsend` | other | `omarchy-nix modules/packages.nix:88` | Ⓝ | ❌ | ❌ | ✅ | LAN file sharing |
| 203 | `obs-studio` | media | `omarchy-nix modules/packages.nix:91` | Ⓝ | ❌ | ❌ | ✅ | video production |
| 204 | `kdenlive` (conditional on `pkgs ? kdenlive`) | media | `omarchy-nix modules/packages.nix:93` | Ⓝ | ❌ | ❌ | ✅⚠️ | optional; not always available |
| 205 | `voxtype` (omarchy.voxtype.enable) | dev-tool | `omarchy-nix modules/packages.nix:100` | Ⓝ | ❌ | ❌ | ❌ | not enabled on t14 |
| 206 | `wtype` (voxtype) | other | `omarchy-nix modules/packages.nix:101` | Ⓝ | ❌ | ❌ | ❌ | not enabled on t14 |
| 207 | `signal-desktop` | other | `omarchy-nix modules/packages.nix:108` | Ⓝ | ❌ | ❌ | ✅ | |
| 208 | `typora` | other | `omarchy-nix modules/packages.nix:111` | Ⓝ | ❌ | ❌ | ✅ | proprietary |
| 209 | `dropbox` | other | `omarchy-nix modules/packages.nix:112` | Ⓝ | ❌ | ❌ | ✅ | proprietary |
| 210 | `spotify` | media | `omarchy-nix modules/packages.nix:113` | Ⓝ | ❌ | ❌ | ✅ | proprietary |
| 211 | `github-desktop` | dev-tool | `omarchy-nix modules/packages.nix:117` | Ⓝ | ❌ | ❌ | ✅ | |
| 212 | `gh` (omarchy) | dev-tool | `omarchy-nix modules/packages.nix:118` | Ⓝ | ❌ | ❌ | ✅ | also in HM `programs.gh` via `home-linux/gh.nix` (all 3 hosts) |
| 213 | `docker-compose` | vm | `omarchy-nix modules/packages.nix:121` | Ⓝ | ❌ | ❌ | ✅ | |
| 214 | `docker-buildx` | vm | `omarchy-nix modules/packages.nix:122` | Ⓝ | ❌ | ❌ | ✅ | |
| 215 | `mariadb.client` | dev-tool | `omarchy-nix modules/packages.nix:125` | Ⓝ | ❌ | ❌ | ✅ | |
| 216 | `postgresql.lib` | dev-tool | `omarchy-nix modules/packages.nix:126` | Ⓝ | ❌ | ❌ | ✅ | |
| 217 | `ffmpegthumbnailer` | media | `omarchy-nix modules/packages.nix:129` | Ⓝ | ❌ | ❌ | ✅ | nautilus preview |
| 218 | `sushi` | other | `omarchy-nix modules/packages.nix:130` | ⓖ | ❌ | ❌ | ✅ | nautilus previewer |
| 219 | `gnome-keyring` (omarchy) | keyring | `omarchy-nix modules/packages.nix:133` | ⓖ | ❌ | ❌ | ✅ | duplicate of #139 |
| 220 | `libsecret` (omarchy) | keyring | `omarchy-nix modules/packages.nix:134` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #63 |
| 221 | `qtwayland` | dev-tool | `omarchy-nix modules/packages.nix:137` | Ⓝ | ❌ | ❌ | ✅ | |
| 222 | `qtstyleplugin-kvantum` | theme | `omarchy-nix modules/packages.nix:138` | Ⓝ | ❌ | ❌ | ✅ | |
| 223 | `walker` (omarchy input) | launcher | `omarchy-nix modules/nixos/system.nix:132` | Ⓝ | ❌ | ❌ | ✅ | t14 launcher (replaces rofi) |
| 224 | `elephant-with-providers` | launcher | `omarchy-nix modules/nixos/system.nix:133` | Ⓝ | ❌ | ❌ | ✅ | walker backend |
| 225 | `wl-clipboard` (PATH helper for elephant) | shell-util | `omarchy-nix modules/nixos/system.nix:36` | Ⓝ | ❌ | ❌ | ✅⚠️ | only on elephant wrapper PATH |
| 226 | `libqalculate` (PATH helper) | other | `omarchy-nix modules/nixos/system.nix:37` | Ⓝ | ❌ | ❌ | ✅⚠️ | elephant calculator provider |
| 227 | `bluez` (PATH helper) | networking | `omarchy-nix modules/nixos/system.nix:39` | Ⓝ | ❌ | ❌ | ✅⚠️ | bluetooth stack |
| 228 | `noto-fonts`, `noto-fonts-color-emoji`, `caskaydia-mono`, `jetbrains-mono`, `omarchy-font` | font | `omarchy-nix modules/nixos/system.nix:244-261` | Ⓝ | ❌ | ❌ | ✅ | omarchy icon font U+E900 |
| — | **HOME-MANAGER PROGRAMS (no separate package install; declared via `programs.*`)** |||||||
| 229 | `mate-terminal` | terminal | `home-linux/mate.nix:250-262, 77` | ⓜ | ✅ (xdg desktop file) | ✅ | ❌ | HM dconf `org/mate/desktop/applications/terminal.exec = "mate-terminal"`; also rofi terminal in `home-linux/rofi.nix:112` |
| 230 | `rofi` | launcher | `home-linux/rofi.nix:109-130` | Ⓝ | ✅ | ✅ | ❌ | t14 uses walker instead |
| 231 | `picom` | compositor | `home-linux/picom.nix:4-45` | Ⓝ | ✅ | ✅ | ❌ | t14 uses hyprland compositor |
| 232 | `git` (HM) | git | `home-linux/git.nix:4-13` | Ⓝ | ✅ | ✅ | ✅ | programs.git (openpgp signing, delta pager) |
| 233 | `gh` (HM) | dev-tool | `home-linux/gh.nix:4-19` | Ⓝ | ✅ | ✅ | ✅ | programs.gh + alias `co = "pr checkout"` |
| 234 | `tmux` (HM) | multiplexer | `home-linux/tmux.nix:30-50` | Ⓝ | ✅ | ✅ | ✅ | programs.tmux; t14 uses `lib.mkForce` to override omarchy's `C-Space` prefix; plugins: `resurrect, continuum, sessionist, yank, vim-tmux-navigator` |
| 235 | `neovim` (HM) | text-editor | `home-linux/neovim.nix:21` | Ⓝ | ✅ (custom LazyVim) | ✅ (custom LazyVim) | ✅ (omarchy minimal) | rogs/tc disable `programs.neovim` (`lib.mkForce false`) and git-clone LazyVim config via `home.activation.ensureNvimConfig:64-74`; t14 uses omarchy's `programs.neovim` (`omarchy home-manager/default.nix:259-263`) |
| 236 | `ghostty` (HM) | terminal | `home-linux/ghostty.nix:20-71` | Ⓝ | ✅ | ✅ | ✅ (forced) | t14 uses `lib.mkForce` to replace omarchy's `themes.omarchy` and JetBrainsMono 9 with CaskaydiaCove 11 + nix-colors palette |
| 237 | `kitty` (HM) | terminal | `home-linux/kitty.nix:4-66` | Ⓝ | ✅ | ✅ | ✅ | t14 imports `home-linux/kitty.nix` from `hosts/t14/home/default.nix:20` |
| 238 | `alacritty` (HM) | terminal | `home-linux/alacritty.nix:4-9` | Ⓝ | ✅ | ✅ | ✅ | t14 also gets omarchy's `programs.alacritty` |
| 239 | `zsh` (HM) | shell | `home-linux/shell.nix:10-86` | Ⓝ | ✅ | ✅ | ✅ | zsh with prezto, aliases; t14 disables omarchy's `programs.zsh.zplug` and `programs.starship` |
| 240 | `ssh` (HM) | remote-shell | `home-linux/ssh.nix:8-82` | Ⓝ | ✅ | ✅ | ✅ | programs.ssh with hosts: oneplus5, thinkcentre, mact2, rog, t14 (with identities) |
| 241 | `opencode` (HM) | dev-tool | `shared/opencode.nix:320-365` | Ⓝ | ✅ | ✅ | ✅ | home.packages: `gentle-ai`, `engram`; exports API keys from sops |
| 242 | `gentle-ai` (custom HM pkg) | dev-tool | `pkgs/gentle-ai/default.nix:9` | Ⓝ | ✅ | ✅ | ✅ | v1.42.0; OpenCode ecosystem |
| 243 | `engram` (custom HM pkg) | dev-tool | `pkgs/engram/default.nix:9` | Ⓝ | ✅ | ✅ | ✅ | v1.16.3; persistent memory for AI agents |
| 244 | `nixos-scripts` (custom HM pkg) | dev-tool | `pkgs/nixos-scripts/default.nix` | Ⓝ | ✅ | ✅ | ✅ | bundles `work-flow`, `start-work`, `finish-work`, `abort-work`, `git-flow`, `oc-wt`, `format-nix`, `nixos-build`, `export-mate-config` |
| 245 | `conky` (rog HM scripts) | system-monitor | `home-linux/conky-rog.nix:258-263` | Ⓝ | ✅ | ❌ | ❌ | home.packages: `conkyWrapper` (LOCALE fix), `installDaysScript`, `gpuTempsScript`, `fanSpeedScript`; autostart |
| 246 | `conky` (thinkcentre HM scripts) | system-monitor | `home-linux/conky-thinkcentre.nix:254-259` | Ⓝ | ❌ | ✅ | ❌ | same scripts as rog, different network interface names |
| 247 | `remmina` (HM) | remote-desktop | `home-linux/remote-desktop.nix:216-219` | Ⓝ | ✅ | ✅ | ✅ | home.packages: `remmina`, `libsecret`; profiles via `home.file` |
| 248 | `ripgrep` (neovim HM) | shell-util | `home-linux/neovim.nix:7` | Ⓝ | ✅ | ✅ | ✅ | duplicate of #175 (omarchy) |
| 249 | `fd` (neovim HM) | shell-util | `home-linux/neovim.nix:8` | Ⓝ | ✅ | ✅ | ✅ | duplicate of #177 (omarchy) |
| 250 | `tree-sitter` | dev-tool | `home-linux/neovim.nix:9` | Ⓝ | ✅ | ✅ | ✅ | |
| 251 | `python3` (neovim HM) | dev-tool | `home-linux/neovim.nix:11` | Ⓝ | ✅ | ✅ | ✅ | |
| 252 | `git` (neovim HM) | git | `home-linux/neovim.nix:12` | Ⓝ | ✅ | ✅ | ✅ | duplicate of #51 |
| 253 | `lua5_1` | dev-tool | `home-linux/neovim.nix:14` | Ⓝ | ✅ | ✅ | ❌ | |
| 254 | `luarocks` | dev-tool | `home-linux/neovim.nix:15` | Ⓝ | ✅ | ✅ | ❌ | |
| 255 | `icu` | dev-tool | `home-linux/neovim.nix:16` | Ⓝ | ✅ | ✅ | ❌ | |
| 256 | `imv` (omarchy HM) | image-viewer | `omarchy home-manager/imv.nix:1` | Ⓝ | ❌ | ❌ | ✅ | replaces `eom` (rog/tc use eom) |
| 257 | `evince` (omarchy HM) | pdf-viewer | `omarchy home-manager/evince.nix:1` | ⓖ | ❌ | ❌ | ✅ | replaces `atril` |
| 258 | `inotify-tools` (omarchy HM) | shell-util | `omarchy home-manager/light-theme-monitor.nix` | Ⓝ | ❌ | ❌ | ✅ | powers omarchy-theme-monitor user service |
| 259 | `waybar` (omarchy HM) | shell-util | `omarchy home-manager/waybar.nix:22` | Ⓝ | ❌ | ❌ | ✅ | t14 status bar (replaces conky) |
| 260 | `vscode` (omarchy HM) | dev-tool | `omarchy home-manager/vscode.nix` | Ⓝ | ❌ | ❌ | ✅ | programs.vscode with extensions `bbenoist.nix, vscodevim.vim, everforest, tokyo-night` |
| 261 | `zellij` (omarchy HM) | terminal | `omarchy home-manager/zellij.nix` | Ⓝ | ❌ | ❌ | ✅ | tmux alternative (not started by default) |
| 262 | `starship` (omarchy HM) | shell | `omarchy home-manager/starship.nix` | Ⓝ | ❌ | ❌ | ❌ (disabled) | t14 uses `lib.mkForce false` in `omarchy.nix:98` to keep rog/tc pure-prezto consistency |
| 263 | `direnv` (omarchy HM) | dev-tool | `omarchy home-manager/direnv.nix` | Ⓝ | ❌ | ❌ | ✅ | |
| 264 | `mako` (omarchy HM) | other | `omarchy home-manager/mako.nix` | Ⓝ | ❌ | ❌ | ✅ | notification daemon (MATE's mate-notification-daemon equivalent) |
| 265 | `hyprland` (omarchy HM) | compositor | `omarchy home-manager/hyprland.nix` | Ⓝ | ❌ | ❌ | ✅ | t14 compositor |
| 266 | `hyprlock` (omarchy HM) | other | `omarchy home-manager/hyprlock.nix` | Ⓝ | ❌ | ❌ | ✅ | lock screen |
| 267 | `hyprpaper` (omarchy HM) | theme | `omarchy home-manager/hyprpaper.nix` | Ⓝ | ❌ | ❌ | ✅ | wallpaper |
| 268 | `hyprsunset` (omarchy HM) | other | `omarchy home-manager/hyprsunset.nix` | Ⓝ | ❌ | ❌ | ✅ | blue-light |
| 269 | `hypridle` (omarchy HM) | other | `omarchy home-manager/hypridle.nix` | Ⓝ | ❌ | ❌ | ✅ | idle daemon (overridden in `omarchy.nix:126-149`) |
| 270 | `hyprpolkitagent` | other | `omarchy home-manager/hyprland.nix` | Ⓝ | ❌ | ❌ | ✅ | polkit agent |
| 271 | `uwsm` (system) | other | `omarchy system.nix:92` | Ⓝ | ❌ | ❌ | ✅ | UWSM (Universal Wayland Session Manager) |
| 272 | `greetd`, `tuigreet` | other | `omarchy system.nix:95-119` | Ⓝ | ❌ | ❌ | ✅ | login manager |
| 273 | `plymouth-theme-omarchy` | theme | `omarchy packages/plymouth-theme-omarchy.nix` | Ⓝ | ❌ | ❌ | ✅ | splash screen |
| 274 | `greetd` service | other | `omarchy system.nix` | Ⓝ | ❌ | ❌ | ✅ | greeter for Hyprland |
| 275 | `printing` (CUPS) | other | `omarchy system.nix:197-200` | Ⓝ | ❌ | ❌ | ✅ | CUPS + cups-browsed + cups-pdf |
| 276 | `power-profiles-daemon` | other | `omarchy system.nix:203` | Ⓝ | ❌ | ❌ | ✅ | power profiles |
| 277 | `nix-ld` (system) | dev-tool | `omarchy system.nix:137-139` | Ⓝ | ❌ | ❌ | ✅ | runs unpatched binaries (Python venvs) |
| 278 | `iwd` (system) | networking | `omarchy system.nix:215` | Ⓝ | ❌ | ❌ | ✅ | wireless daemon (rog/tc use wpa_supplicant via NetworkManager) |
| 279 | `kdePackages.qtwayland` (omarchy) | dev-tool | `omarchy packages.nix:137` | Ⓝ | ❌ | ❌ | ✅ | duplicate of #221 (same line) |
| 280 | `wayvnc` (system) | remote-desktop | `omarchy-nix modules/nixos/wayvnc.nix` (gated by `omarchy.wayvnc.enable = true` in `hosts/t14/default.nix:155`) | Ⓝ | ❌ | ❌ | ✅ | VNC server in Hyprland session |
| 281 | `openfang` (rog HM autostart) | dev-tool | `home-linux/openfang.nix:130-150` | Ⓝ | ✅ (autostart) | ❌ | ❌ | systemd user service; reads sops secrets; only enabled for rog |
| 282 | `github-mcp-server` (system wrapper) | dev-tool | `modules/features/services/github-mcp-server.nix` | Ⓝ | ❌ | ❌ | ✅ | t14 only (per `hosts/t14/default.nix:57`); wraps upstream `github-mcp-server` with sops-provided PAT |
| 283 | `mouse-wiggle` (t14 HM script) | other | `hosts/t14/home/mouse-wiggle.nix:5-49` | Ⓝ | ❌ | ❌ | ✅ | script prevents hyprlock during long tasks; not autostarted |
| 284 | `conky-launcher` (rog HM) | system-monitor | `home-linux/conky-rog.nix:250-254` | Ⓝ | ✅ (autostart) | ❌ | ❌ | autostart desktop file |
| 285 | `conky-launcher` (tc HM) | system-monitor | `home-linux/conky-thinkcentre.nix:246-250` | Ⓝ | ❌ | ✅ (autostart) | ❌ | autostart desktop file |

## MATE-native vs GNOME-native vs Neutral breakdown

### MATE-native (rog + thinkcentre, NOT t14)

Defined in `modules/base/profiles/mate.nix`:
- `atril` (pdf), `caja` (files), `engrampa` (archive), `eom` (image),
  `marco` (wm), `pluma` (editor), `mate-panel`, `mate-sensors-applet`,
  `mate-user-share`, `materia-theme`

Defined in `home-linux/mate.nix`:
- `mate-terminal` (terminal default in dconf)
- `org/mate/caja/*` dconf, `org/mate/marco/*`, `org/mate/panel/*`,
  `org/mate/pluma`, `org/mate/power-manager`, `org/mate/screensaver`,
  `org/mate/notification-daemon`, `org/mate/desktop/background`,
  `org/mate/desktop/interface`

Defined in `home-linux/conky-{rog,thinkcentre}.nix` (X11-only conky,
  set `out_to_wayland = false`):
- `conky` (binary from base.nix), `conkyWrapper`, `installDaysScript`,
  `gpuTempsScript`, `fanSpeedScript`, `conky-launcher`

Defined in `home-linux/mate-rog-autostart.nix`:
- `hexchat` autostart desktop file

Defined in `modules/features/services/xrdp.nix`:
- `mate-polkit` (polkit agent), `mate-session-manager` (in `xrdpMateSession`)

### GNOME-native (t14 only, NOT rog/thinkcentre)

Defined in `modules/base/profiles/gnome.nix`:
- `gnome-system-monitor`

Defined via `my.desktop.suite = "gnome"` in `hosts/t14/default.nix:161` (only adds
  one package — omarchy-nix provides all other GNOME apps).

From omarchy-nix:
- `nautilus` (file manager), `gnome-calculator`, `loupe` (image),
  `sushi` (preview), `gnome-keyring`, `gnome-themes-extra`,
  `evince` (PDF), `gnome-system-monitor` (from `gnome.nix`),
  `bibata-cursors` (cursor), `Adwaita-dark` (theme default)

### Neutral (all 3 hosts share via profiles, with optional omarchy overrides)

Anything defined in `modules/base/profiles/{base,dev,media,virt,browsers}.nix`
is shared. The notable exception is the **suite** profile.

## Duplicates

These are *intentional* duplicates because t14 is wired through omarchy-nix
which redeclares what `profiles/base.nix` already installs. Nix deduplicates
builds, so this is harmless on disk but adds eval-time work.

| Package        | Defined in (system)                            | Defined in (omarchy, t14 only)                |
|----------------|------------------------------------------------|-----------------------------------------------|
| `git`          | `base.nix:67`                                  | `omarchy packages.nix:11`                     |
| `gnumake`      | `dev.nix:9`                                    | `omarchy packages.nix:62`                     |
| `lazygit`      | `base.nix:74`                                  | `omarchy packages.nix:65`                     |
| `lazydocker`   | `base.nix:75`                                  | `omarchy packages.nix:66`                     |
| `btop`         | `base.nix:32`                                  | `omarchy packages.nix:67`                     |
| `fastfetch`    | `base.nix:30`                                  | `omarchy packages.nix:69`                     |
| `ffmpeg`       | `media.nix:9`                                  | `omarchy packages.nix:16`                     |
| `mpv`          | `media.nix:7`                                  | `omarchy packages.nix:82`                     |
| `wiremix`      | `media.nix:8`                                  | `omarchy packages.nix:44`                     |
| `gnome-themes-extra` | `base.nix:93`                              | `omarchy packages.nix:25`                     |
| `gnome-keyring`| `hardware/keyring.nix:6`                       | `omarchy packages.nix:133`                    |
| `libsecret`    | `base.nix:81` + `hardware/keyring.nix:7` + `home-linux/remote-desktop.nix:218` (3 declarations in this repo alone) | `omarchy packages.nix:134`                    |
| `curl`         | `base.nix:14`                                  | `omarchy packages.nix:59`                     |
| `wget`         | `base.nix:15`                                  | `omarchy packages.nix:61`                     |
| `unzip`        | `base.nix:18`                                  | `omarchy packages.nix:60`                     |
| `fzf`          | `base.nix:11`                                  | `omarchy packages.nix:53`                     |
| `jq`           | `base.nix:79`                                  | `omarchy packages.nix:58`                     |
| `nodejs`       | `dev.nix:20`                                   | `home-linux/neovim.nix:10`                    |
| `ripgrep`      | `home-linux/neovim.nix:7`                      | `omarchy packages.nix:55`                     |
| `fd`           | `home-linux/neovim.nix:8`                      | `omarchy packages.nix:57`                     |
| `ghostty`      | `base.nix:86`                                  | `omarchy packages.nix:32`                     |
| `avahi`        | `base.nix:62`                                  | `omarchy system.nix:182-193` (services.avahi) |
| `coreutils`    | `base.nix:42`                                  | `omarchy system.nix:34` (PATH wrapper)        |
| `imagemagick`  | `base.nix:27`                                  | `omarchy system.nix:38` (PATH wrapper)        |
| `gh` (HM)      | `home-linux/gh.nix` (all 3)                    | `omarchy packages.nix:118` (t14 system)       |
| `google-chrome-stable` (chrome-apps.nix) | `browsers.nix:6`         | (no omarchy dup — omarchy uses brave/chromium)|

## Custom (locally-built) packages

Defined in `pkgs/` and surfaced via `overlays/linux.nix:7-29`:

| Package                  | Version | Used on | Notes |
|--------------------------|---------|---------|-------|
| `asus-fan-control`       | upstream git | rog only | Service `afc.service` for ASUS laptop fan curves (`pkgs/asus-fan-control/default.nix`) |
| `pipewire-module-xrdp`   | 0.2     | rog only | XRDP audio passthrough (`pkgs/pipewire-module-xrdp/default.nix`) |
| `engram`                 | 1.16.3  | all 3   | Persistent memory for AI agents (`pkgs/engram/default.nix`) — used by OpenCode |
| `gentle-ai`              | 1.42.0  | all 3   | OpenCode ecosystem configurator with SDD workflow (`pkgs/gentle-ai/default.nix`) |
| `gentle-ai-assets`       | (same)  | all 3   | Bundled skills/commands for OpenCode |
| `gentle-ai-assets-vanilla` | (same) | all 3   | Vanilla asset variant (no theme) |
| `engram-assets`          | (same)  | all 3   | Bundled engram OpenCode plugin |
| `engram-assets-vanilla`  | (same)  | all 3   | Vanilla asset variant |
| `secret-guard-assets`    | (same)  | all 3   | secret-guard OpenCode plugin assets |
| `opencode`               | 1.17.11 | all 3   | Pre-built CLI from upstream releases (`pkgs/opencode/default.nix` — `fetchurl`) |
| `opencode-npm-packages`  | (same)  | all 3   | Pre-built node_modules for OpenCode TUI |
| `openfang`               | 0.6.4   | all 3 (system) / rog only (autostart) | Local-first AI coding agent (`pkgs/openfang/default.nix` — `fetchurl`); HM autostart in `home-linux/openfang.nix` |
| `nixos-scripts`          | 0.1.0   | all 3 (HM `home.packages`) | Bundles `bin/{work-flow,start-work,finish-work,abort-work,list-work,git-flow,oc-wt,format-nix,nixos-build,export-mate-config}` (`pkgs/nixos-scripts/default.nix`) |

## Notes & observations

1. **Profile chain ignores t14's path.** `modules/profiles/base.nix` imports
   `../base/packages.nix` plus networking/desktop/boot. `modules/profiles/desktop.nix`
   adds fonts/i18n/kmscon/keyring. `modules/profiles/server.nix` adds xrdp,
   github-mcp, wol, docker. t14 imports **`modules/base/packages.nix` directly**
   (`hosts/t14/default.nix:28`) and bypasses the chain — but because
   `modules/base/packages.nix` already pulls in all six profiles (base + suite +
   dev + media + virt + browsers), the *package set* is effectively identical
   to what rog/thinkcentre get, except t14 swaps `mate.nix` for `gnome.nix`.

2. **T14 is double-served.** It gets both the `modules/base/packages.nix`
   baseline (via `hosts/t14/default.nix:28`) AND omarchy-nix's
   `modules/packages.nix` (via `inputs.omarchy-nix.nixosModules.default` from
   `flake.nix:214`). This is why ~25 packages appear duplicated in the table.

3. **Suite switcher is a single line.** Changing `my.desktop.suite = "mate"`
   → `"gnome"` in a host's `default.nix` is the only thing that swaps the DE
   flavor (caja/nautilus, atril/evince, etc.). See `modules/base/options.nix`
   for the option declaration and `modules/base/packages.nix:21-27` for the
   suite selection logic.

4. **MATE-only on rog/tc, not pure-MATE.** rog and thinkcentre get the MATE
   suite but **also** pull in all the GNOME-adjacent packages from
   `base.nix` (gnome-themes-extra, gtk-engine-murrine, adwaita-icon-theme,
   networkmanagerapplet, gparted, hexchat, gnome-keyring). MATE here is
   "MATE-panel with GTK3/libsecret/keyring/GNOME-icon-theme mixed in".

5. **Per-host HM extras are appended, not duplicated.** rog appends
   `remote-desktop, picom, mate-rog-autostart, conky-rog, openfang` to the
   shared list (`hosts/rog/home/modules.nix:7-12`). thinkcentre appends
   `remote-desktop, picom, conky-thinkcentre` (`hosts/thinkcentre/home/modules.nix:8-10`).
   t14 has its **own curated** import list (`hosts/t14/home/omarchy.nix:39-90`)
   that omits `rofi, mate, chrome-apps, theme` (see file comment lines 14-26).

6. **Hexchat autostart is rog-only.** `home-linux/mate-rog-autostart.nix` is
   imported only by rog's `home/modules.nix`. The package itself is in
   `base.nix:102` (so also on thinkcentre), but the autostart desktop file
   only fires on rog.

7. **Conky is dual-rigged, not portable.** `conky-rog.nix` and
   `conky-thinkcentre.nix` are 95% identical but hard-code different network
   interface names (`enp3s0` vs `enp0s31f6`). Both `conky-rog.nix` and
   `conky-thinkcentre.nix` deploy `conky.conf`, `logo.lua`, and the
   `conky-launcher` autostart. Conky is **not** deployed on t14 (omarchy uses
   waybar).

8. **Openfang is "rog-only" in userland.** The package is installed on all
   three hosts via `modules/base/profiles/dev.nix:30`, but the systemd user
   service and config file in `home-linux/openfang.nix` are imported only
   for rog.

9. **Remmina is on all 3, but profiles are different.** The Remmina
   `.remmina` profiles deploy RDP/VNC targets that work from anywhere;
   rogs/tc get them via `shared-modules.nix`; t14 gets them via the
   explicit import in `hosts/t14/home/omarchy.nix:79`.

10. **There is NO `chrome-apps.nix` on t14.** omarchy-nix manages its own
    webapp launcher system (`~/.config/omarchy/webapp-icons`); the
    `chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default.desktop` (X/Twitter) and
    `poweroff.desktop` / `reboot.desktop` are only on rog/thinkcentre.

11. **Picom is X11-only and MATE-onwards.** `home-linux/picom.nix` enables
    the picom compositor on rog/thinkcentre. t14 doesn't need it because
    Hyprland has its own compositor (and the comment in
    `hosts/t14/home/omarchy.nix:25-26` explicitly excludes picom).

12. **The `materia-theme` is only consumed by rog/tc.** It's installed
    system-wide in `profiles/mate.nix:19` but `home-linux/theme.nix:14-15`
    only references it on hosts that import `home-linux/theme.nix` (rog,
    thinkcentre — t14 omits it). t14 gets `Adwaita-dark` from omarchy
    `home-manager/default.nix:240-243`.

13. **VNC server is t14-only.** `omarchy.wayvnc.enable = true` in
    `hosts/t14/default.nix:155` enables `programs.wayvnc` + the
    `omarchy-vnc` systemd user service. rog/thinkcentre have no VNC server.

14. **Three browser overlap pattern.** Both base (`browsers.nix`) and
    omarchy (`packages.nix`) install Chromium-derived browsers. On rog/tc
    `google-chrome, microsoft-edge, chromium, brave` are all available. On
    t14, the base `browsers.nix` adds the same four, AND omarchy installs
    `brave` again (or `chromium` if `omarchy.browser != "brave"`). The
    active browser on t14 is `brave` (set via `omarchy.browser`).

15. **github-mcp-server is t14-only.** Imported in
    `hosts/t14/default.nix:57`. Wraps upstream `pkgs.github-mcp-server` and
    pulls `GITHUB_PERSONAL_ACCESS_TOKEN` from a sops secret.

16. **Hyprland input not from nixpkgs.** omarchy-nix uses
    `inputs.hyprland.packages.${system}.hyprland` (pinned to v0.54.3 in
    `omarchy-nix/flake.nix`) rather than nixpkgs' `hyprland`.

## Ready for Proposal

**Yes.** The audit is complete and the table is the primary input for
proposal work that wants to:

- Consolidate `libsecret` (3 declarations in this repo + 1 in omarchy).
- Drop `profiles/base.nix` packages that omarchy already installs for t14
  (e.g. `git`, `gnumake`, `lazygit`, `lazydocker`, `btop`, `fastfetch`).
- Decide whether `profiles/gnome.nix` (which currently only adds
  `gnome-system-monitor`) should grow, or whether t14 should rely entirely
  on omarchy for the GNOME experience.
- Decide whether to keep `meld`, `hexchat`, `windsurf`, `flatpak`, `popsicle`
  on the server-class hosts (rog/tc) where they may be unused.
- Resolve the open question of whether `conky-{rog,thinkcentre}.nix` can be
  parameterised by interface name to share a single module.

## Relevant Files

- `sdd/changes/app-audit-per-host/exploration.md` — this file
- `sdd/changes/host-desktop-suite-separation/` — sibling change that split
  out the suite profile mechanism (this audit relies on that machinery)
- `modules/base/profiles/{base,mate,gnome,dev,media,virt,browsers}.nix`
- `modules/base/packages.nix` — profile composition entry point
- `modules/hardware/keyring.nix` — `gnome-keyring` + `libsecret`
- `modules/features/services/xrdp.nix` — xrdp-only system packages
- `hosts/{rog,thinkcentre,t14}/default.nix`
- `home-linux/shared-modules.nix` — canonical HM list
- `home-linux/{mate,rofi,picom,remote-desktop,chrome-apps,conky-rog,conky-thinkcentre,mate-rog-autostart,openfang}.nix`
- `home-linux/{git,gh,tmux,neovim,ghostty,kitty,alacritty,ssh,theme,shell,base}.nix`
- `hosts/{rog,thinkcentre}/home/modules.nix` — per-host HM module lists
- `hosts/t14/home/{omarchy.nix,default.nix,hypr/*.nix,mouse-wiggle.nix}`
- `pkgs/{asus-fan-control,pipewire-module-xrdp,engram,gentle-ai,opencode,openfang,nixos-scripts}/default.nix`
- `overlays/linux.nix`
- `flake.nix`, `flake.lock` (omarchy-nix rev `662b0dcbc9662a00558f12330dd43795d368bb06`)
- `/nix/store/0wyzizadp6z67pk2m9b68spg3kkydh2n-source/` (resolved omarchy-nix source at the pinned rev)
