# SDD Research Evidence — Quattro v4 Inventory

```yaml
schema: gentle-ai.sdd-research/v1
revision: 2
outcome: done
change: migrate-t14-omarchy-quattro-v4
accessed_at: 2026-09-14
capability:
  schema: gentle-ai.sdd-research-capability/v1
  revision: 1
  grants:
    documentation: [context7]
    open-web: [github, exa]
```

## Retained Request

Produce a current, auditable inventory for the `migrate-t14-omarchy-quattro-v4` OpenSpec change. The requested inventory must identify Omarchy Quattro components, assets, scripts, and configuration to port; map every `port now` item to its omarchy-nix v3 replacement(s), repository owner, required Nix deviation, dependencies, and validation and rollback concerns. It must classify every candidate as `port now`, `retain as-is`, `defer`, or `explicitly exclude`; cover Quickshell shell services, Hyprland Lua, NetworkManager, PAM/lock/polkit, themes, scripts/runtime assets, and retained t14 HDM/VNC/Edge integration; and identify stale documentation claims.

## Admission

| Requested class | Declared grant | Admission | Used sources |
|---|---|---|---|
| `documentation` | `context7` | Admitted | D1–D2 |
| `open-web` | `github`, `exa` | Admitted | W1–W9 |

MCP research was completed before either local repository was inspected. Local reads below are direct implementation context requested for the inventory; they are not substitutes for admitted external evidence.

## Executive Finding

Quattro’s porting unit is the single long-running Quickshell runtime plus its Lua configuration and supporting declarative system integration, not a one-for-one port of the v3 daemon stack. Therefore the portable v4 line should port the Quickshell shell, its IPC launch/restart bridge, Lua defaults and user override layout, NetworkManager-backed network panel, Quickshell lock/PAM/polkit integration, and the Quattro theme/runtime assets together; it should remove the replaced v3 shell assets rather than retaining parallel daemons.

The current upstream is `omacom/omarchy` on its `quattro` branch, not `basecamp/omarchy`. The v3 Nix port is confirmed locally and through `glats/omarchy-nix` prior art to start `swaybg`, `hyprpolkitagent`, `waybar`, `swayosd`, and Walker separately, and to retain separate Mako, Hyprlock, Hypridle, theme-generation, and iwd modes. [W1, W2, W3, W6, L1, L2]

## Sources

| ID | Class | Title and publisher | URL | Accessed | Relevant excerpt / observation |
|---|---|---|---|---|---|
| D1 | documentation | Quickshell Hyprland and WlSessionLock API, Quickshell | https://quickshell.org/docs/master/types/Quickshell.Hyprland/Hyprland | 2026-09-14 | Quickshell has direct Hyprland state/dispatch APIs; `WlSessionLock` must be set `locked = true` to activate. |
| D2 | documentation | PolkitAgent API, Quickshell | https://quickshell.org/docs/master/types/Quickshell.Services.Polkit/PolkitAgent | 2026-09-14 | The agent exposes registration and authentication-flow state. |
| W1 | open-web | Quattro release notes, omacom | https://github.com/omacom/omarchy/releases | 2026-09-14 | Quattro replaces Waybar, Walker, Mako, SwayOSD, Hyprlock, Hypridle, Swaybg, and polkit-gnome with one Quickshell shell; it also moves Hyprland to Lua and Wi-Fi to NetworkManager. |
| W2 | open-web | Omarchy shell, omacom | https://github.com/omacom/omarchy/blob/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/shell/README.md | 2026-09-14 | Hyprland starts one shell per graphical session; the shell hosts plugins and has IPC plus `shell.json` configuration. |
| W3 | open-web | First-party shell plugins, omacom | https://github.com/omacom/omarchy/blob/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/shell/plugins/README.md | 2026-09-14 | Lists the shipped plugins and records the Quickshell lock and polkit replacements. |
| W4 | open-web | Quattro Hyprland configuration, omacom | https://github.com/omacom/omarchy/tree/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/config/hypr | 2026-09-14 | User configuration consists of Lua files for autostart, bindings, input, look-and-feel, monitors, and `hyprland.lua`. |
| W5 | open-web | Default Hyprland autostart, omacom | https://github.com/omacom/omarchy/blob/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/default/hypr/autostart.lua | 2026-09-14 | Imports the graphical-session environment, launches the shell, initializes power profiles and monitor watching, then runs post-boot hooks. |
| W6 | open-web | Quattro lock configuration, omacom | https://github.com/omacom/omarchy/blob/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/bin/omarchy-apply-lock | 2026-09-14 | Installs separate password and conditional fingerprint PAM service files for the Quickshell lock flow. |
| W7 | open-web | Networking manual, omacom | https://github.com/omacom/omarchy/blob/86a2e5830eae4d660a66df8cf37f0a35bf4fe8a2/manual/35-networking.md | 2026-09-14 | Omarchy networking is NetworkManager-backed and exposed through the shell panel, `nmtui`, and CLI. |
| W8 | open-web | Quattro v4.0.0 release, omacom | https://github.com/omacom/omarchy/releases/tag/v4.0.0 | 2026-09-14 | Expanded theme colors generate btop, Neovim, and VS Code configuration; `shell.toml` is a watched machine override. |
| W9 | open-web | Quattro release / migration notes, omacom | https://github.com/omacom/omarchy/pull/6231 | 2026-09-14 | The NetworkManager/iwd handoff and shell replacement are migration-sensitive; legacy standalone daemons are removed. |
| L1 | local inspection | Current `glats/omarchy-nix` v3 Home Manager composition | `/home/glats/Project/omarchy-nix/modules/home-manager/default.nix` | 2026-09-14 | Imports the separate v3 shell modules and deploys their runtime assets and scripts. |
| L2 | local inspection | Current `glats/omarchy-nix` v3 Hyprland autostart | `/home/glats/Project/omarchy-nix/modules/home-manager/hyprland/autostart.nix` | 2026-09-14 | Starts Swaybg, Hyprpolkitagent, Waybar, SwayOSD, monitor watcher, and Walker separately. |
| L3 | local inspection | Current v3 Nix networking and PAM integration | `/home/glats/Project/omarchy-nix/modules/nixos/system.nix` | 2026-09-14 | Defines Hyprlock PAM and both `nm-iwd` and standalone-iwd paths. |
| L4 | local inspection | Current v3 theme generator | `/home/glats/Project/omarchy-nix/modules/home-manager/theme-generator.nix` | 2026-09-14 | Generates v3 daemon-specific theme files, including Mako, SwayOSD, Walker, Waybar, Hyprlock, and Hyprland. |
| L5 | local inspection | Current t14 Omarchy and integration configuration | `/home/glats/.nixos/hosts/t14/omarchy-config.nix`, `/home/glats/.nixos/hosts/t14/home/omarchy.nix`, `/home/glats/.nixos/hosts/t14/default.nix` | 2026-09-14 | t14 uses standalone iwd, a local Waybar unit, HDM, WayVNC in user and greeter sessions, and an XWayland Edge wrapper. |

## Inventory and Classification

Classifications are implementation recommendations derived from the approved change scope. They are deliberately separate from product confirmation; this research neither implements nor confirms a product decision.

| Classification | Quattro item to carry or retain | v3 replacement / current locus | Owner repository | Nix deviation and dependencies | Validation and rollback concern | Evidence |
|---|---|---|---|---|---|---|
| **port now** | `shell/` runtime: one `omarchy-shell`, plugin registry, built-in bar, menu/launcher, notifications, audio/Bluetooth/monitor/network/power panels, media/battery/idle/nightlight services, OSD, image picker, clipboard, reminders, lock, and polkit plugins; plus default `shell.json`. | Replace `waybar.nix`, `walker.nix`, `mako.nix`, `swayosd.nix`, `swaybg.nix`, `hypridle.nix`, `hyprlock.nix`, `services.hyprpolkitagent`, and the t14 Waybar unit. | Portable port: `glats/omarchy-nix`; design source: `omacom/omarchy`. | Package Quickshell and ship QML/assets from immutable Nix outputs; start exactly one shell from the graphical Hyprland session, not one process per plugin. Preserve writable user configuration separately from store defaults. Depends on coherent t14 nixpkgs/Home Manager/Qt/Quickshell boundary. | Smoke test a fresh graphical session, shell IPC ping, every core panel, notification, OSD, lock, and a shell restart. Keep v3 input and known-good generation selectable because failed shell startup otherwise leaves a compositor with no desktop UI. | D1, D2, W1–W3, W5, L1–L2, L5 |
| **port now** | Quattro Lua Hyprland defaults and user override files: bootstrap, `hyprland.lua`, bindings, input, look-and-feel, monitors, autostart, toggles, and app/window rules. | Replace the v3 Home Manager Hyprland split (`configuration.nix`, `bindings.nix`, `input.nix`, `looknfeel.nix`, `windows.nix`, `autostart.nix`, `envs.nix`) and `default/hypr/*.conf` assets. | Portable port: `glats/omarchy-nix`; design source: `omacom/omarchy`. | Deploy Lua defaults as package data and t14 overrides as user-readable files; do not translate Quattro back into Nix Hyprlang attrsets. Keep paths and executable references Nix-store-safe. HDM remains an external t14 owner of monitor output. | Validate Hyprland 0.56-compatible parsing, session autostart order, essential bindings, monitor reload, and t14 keyboard override. Roll back by returning to the v3 Hyprlang configuration and retained generation. | W1, W4–W5, L2, L5 |
| **port now** | NetworkManager-backed Quattro network panel and its supporting runtime/CLI assets. | Replace `omarchy.wifi.backend = "standalone-iwd"`, its unmanaged `wlan0` path, and v3 Wi-Fi launchers/Impala-oriented workflow. Retain the host’s wired, mDNS, netwatch, firewall-off, and NIC-tuning policy. | Portable UI/runtime: `glats/omarchy-nix`; host policy: `.nixos`; design source: `omacom/omarchy`. | Declare NetworkManager directly in Nix and omit Arch pacman migration/handoff scripts. Do not preserve a competing standalone iwd DHCP/DNS owner. Depends on Quattro network plugin, NetworkManager D-Bus service, and t14 network policy review. | Test scan/connect/reconnect, DHCP/DNS, Ethernet, t14 mDNS interface restriction, Docker coexistence, and sleep/resume. Preserve the v3 connection path and a known-good generation until NetworkManager connects before any v3 service is removed. | W1, W7, W9, L3, L5 |
| **port now** | Quickshell lock service, themed polkit agent, and Quattro password/fingerprint PAM service definitions. | Replace Hyprlock, its `hyprlock` PAM service and optional fprint configuration, and `hyprpolkitagent`; retire the t14 Hyprlock visual override. Keep the existing host-wide wheel policy only after an explicit security review. | Portable shell/PAM adaptation: `glats/omarchy-nix`; host policy: `.nixos`; design source: `omacom/omarchy`. | Express PAM declaratively in Nix rather than copying Arch `/etc/pam.d` writer scripts. Preserve service names expected by QML only after verifying the NixOS PAM rendering. Do not assume Quattro’s Arch `system-local-login` include exists on NixOS. Depends on Quickshell WlSessionLock, PolkitAgent, polkit daemon, PAM, and optional fprintd. | Test password lock/unlock, cancel/failure handling, polkit prompt, `pkexec`, and fingerprint fallback with lid closed/open. A broken lock or agent can strand the graphical session; retain v3 Hyprlock/hyprpolkitagent and a console/previous-generation recovery route. | D1–D2, W1, W3, W6, L3, L5 |
| **port now** | Quattro theme model: expanded color inputs, `shell.toml`, shell template assets, theme previews/backgrounds, and generated btop/Neovim/VS Code theme outputs. | Replace v3 `theme-generator.nix` outputs that target Mako, SwayOSD, Walker, Waybar, and Hyprlock; preserve the `glats` palette/backgrounds by porting it into the Quattro theme format. | Portable port: `glats/omarchy-nix`; design source: `omacom/omarchy`. | Materialize themes reproducibly from Nix while allowing Quattro’s per-user watched `~/.config/omarchy/shell.toml` override; do not use the v3 Nix rebuild-on-theme-file watcher. Depends on Quattro shell runtime and the t14 `glats` theme source. | Test theme switch, shell live reflow, wallpaper selection, generated btop/Neovim/VS Code output, and persistence of a user shell override. Roll back to the v3 theme symlink/generator and preserve user backgrounds. | W1, W8, L4, L5 |
| **port now** | Runtime scripts and assets that form the Quattro contract: `omarchy-launch-shell`, `omarchy-shell` IPC wrapper, `omarchy-restart-shell`, shell menu/image-selector bridges, menu JSONC, shell defaults, plugin manifests/QML, and Lua helper/runtime assets. | Replace v3 `omarchy-launch-walker`, `omarchy-restart-walker`, `omarchy-restart-waybar`, `omarchy-restart-mako`, `omarchy-restart-swayosd`, `omarchy-toggle-waybar`, Walker/Elephant menu assets, and daemon signal/restart assumptions in theme scripts. | Portable port: `glats/omarchy-nix`; design source: `omacom/omarchy`. | Package scripts with fixed Nix-store dependencies and pass an explicit `OMARCHY_PATH`; retain user-editable config under XDG paths, not inside the store. Do not port Arch package-update, pacman, ALPM, or migration scripts. | Test shell IPC timeout/failure behavior, restart after configuration change, every converted binding, and no stale daemon references. Keep v3 script directory available through rollback only, not in the v4 runtime PATH. | W2–W5, W8–W9, L1–L2 |
| **retain as-is** | t14 HyprDynamicMonitors configuration and UPower-based lid integration. | No Quattro replacement; HDM is already the local authoritative monitor-profile writer. | `.nixos` host repository. | Source Quattro monitor hooks only after ensuring they do not write the same monitor state. Keep the existing `omarchy.hyprland.lidSwitch.enable = false` intent or its v4 equivalent. Depends on UPower and Hyprland IPC. | Test dock/undock and lid-open/lid-closed profiles before/after shell migration. Roll back independently by retaining HDM files and its user service. | W1, W4–W5, L5 |
| **retain as-is** | User-session and greeter WayVNC configuration, output selection, PAM transport, and port handoff. | No Quattro replacement. | Portable WayVNC module: `glats/omarchy-nix`; t14 selections: `.nixos`. | Keep the existing NixOS/HM and greeter declarative units; only revalidate their ordering against the new Hyprland/Lua session start. Depends on WayVNC, PAM, graphical-session environment, and ReGreet. | Test remote login, user-session handoff, output cycling, and reconnect across a shell restart. Preserve current WayVNC units and previous generation. | L3, L5 |
| **retain as-is** | XWayland Microsoft Edge wrapper, Edge policies, MIME defaults, and Teams wrapper. | No Quattro replacement. | `.nixos` host repository. | Keep this local because it is a t14 workaround and not Omarchy shell behavior; translate only the browser launch binding/variable to the Quattro Lua override. Depends on the wrapped Edge derivation and desktop-entry rewrites. | Test Quattro browser binding, MIME launch, policy loading, and no Wayland flicker regression. Roll back without changing the wrapper. | W4, L5 |
| **retain as-is** | T14 host policy: SOPS wiring, networking tuning, Avahi restrictions, boot/kernel settings, game stack, hardware, and firewall choice. | No Quattro replacement. | `.nixos` host repository. | Keep it outside the portable fork and prevent Arch installer/package policy from entering the host configuration. | Run t14 evaluation plus focused boot/network checks; rollback remains the existing generation rollback. | W8–W9, L5 |
| **defer** | Third-party Quattro plugins, replacement bars, and optional plugin ecosystem. | No v3 replacement required for the approved t14 desktop baseline. | `omacom/omarchy` design source; no ownership transfer until selected. | Plugins are unsandboxed long-running user code; no plugin fetch/install mechanism should be introduced in the base Nix module without a separate security and reproducibility decision. | Do not block the core migration on plugin parity. If later selected, validate source pinning, manifest review, enable/disable behavior, and rollback by removing the plugin configuration. | W2–W3 |
| **defer** | Optional application/default-app parity and Arch-only package/update/provisioning stack. | V3 application modules may continue only when compatible; no automatic Quattro app selection. | Not owned by t14 migration unless separately selected. | Quattro’s Arch packages, pacman/ALPM guard, ISO, snapshots, provisioning, and migration scripts do not map to NixOS. | Keep this out of the desktop cutover acceptance gate. Any later app change needs its own compatibility and license review. | W8–W9 |
| **defer** | T14 keyboard-layout indicator/UI integration. | Existing `kb-layout.sh`/`kb-toggle.sh` were retained partly for Waybar/plugin consumers; Quattro’s built-in bar can own a keyboard widget, but exact hook compatibility was not established. | `.nixos` host repository. | Keep scripts available until the Quattro binding/widget contract is verified; do not copy Waybar-specific configuration into the shell blindly. | Verify ES/Latin-American switch behavior and pre-login indicator separately. Roll back by retaining current scripts and greeter notification path. | W1, W3–W4, L5 |
| **explicitly exclude** | Waybar, Walker, Mako, SwayOSD, Swaybg, Hyprlock, Hypridle, and Hyprpolkitagent configuration/assets/services from the v4 portable runtime. | They are the v3 multi-daemon stack explicitly replaced by Quattro. | `glats/omarchy-nix` removes them; `omacom/omarchy` is the design reference. | Remove only after the complete shell, lock, and network acceptance checks pass; no parallel service autostart. | Parallel daemons create duplicate UI, conflicting locks/notifications, and unclear ownership. Roll back as one v3 generation, not by selectively re-enabling daemons. | W1, W3, L1–L2 |
| **explicitly exclude** | v3 daemon-specific theme files: `mako.ini`, `swayosd.css`, `walker.css`, `waybar.css`, and `hyprlock.conf`; v3 Walker/Elephant menu definitions. | Replaced by Quattro shell themes, `shell.toml`, shell JSON configuration, and menu/plugin assets. | `glats/omarchy-nix`. | Do not generate or source them in v4; retain user data only as rollback material. | Check no v4 binding or theme script references them before deletion. | W1–W3, W8, L1, L4 |
| **explicitly exclude** | Arch-specific Quattro update/migration, pacman, ALPM, installer, ISO, and first-boot provisioning scripts. | No NixOS v3 component replacement. | `omacom/omarchy`; not portable to `glats/omarchy-nix`. | Nix generations, flake locks, and declarative modules are the required Nix deviation. | Porting them would introduce a second package/update authority. Rollback is Nix generation selection, not an Arch migration reversal. | W8–W9 |

## Nix-Specific Deviations Required by the Inventory

1. Upstream’s `/usr/share/omarchy` package layout and imperative upgrade migrations must become immutable Nix package data plus declarative NixOS/Home Manager modules; per-user Quattro configuration remains in XDG paths.
2. Quattro’s Arch PAM-writing helper is reference behavior only. The v4 port must create equivalent NixOS-managed PAM service definitions and verify NixOS include semantics rather than copying Arch PAM files or include names.
3. Upstream’s NetworkManager/iwd handoff scripts are not portable. The Nix change must transition service ownership declaratively and must not leave standalone iwd as a competing DHCP/DNS owner.
4. Quickshell, its Qt libraries, Home Manager, and Hyprland must share the isolated newer t14 package boundary defined by the approved proposal; they must not force the global nixpkgs 26.05 or mact2 boundary to move.
5. HDM, WayVNC, Edge, SOPS, and host network/hardware policy stay in `.nixos`; only the integration points that must follow Lua/shell startup are adapted.

## Stale Documentation Claims

| Location | Stale claim | Evidence and required correction |
|---|---|---|
| `/home/glats/Project/omarchy-nix/AGENTS.md:7–13` | The upstream design reference and `gh api` examples name `basecamp/omarchy`. | Current GitHub evidence is `omacom/omarchy` on `quattro`. Replace both the repository identity and command examples. [W1–W4] |
| `/home/glats/Project/omarchy-nix/AGENTS.md:45–54, 93–141` | The dependency/module/script inventory presents Walker, Waybar, Mako, SwayOSD, Hyprlock, Hypridle, and split Hyprlang Nix modules as the current portable desktop model. | It accurately describes v3, but becomes stale for the planned v4 line. Version or label this section as v3 until the Quattro inventory replaces it; do not describe it as the v4 target. [W1, L1–L4] |
| `/home/glats/.nixos/hosts/t14/home/omarchy.nix:39–50, 95–119, 166–183` | Comments and a local service state that Omarchy supplies/runs Waybar, Walker, Mako, SwayOSD, and Hyprlock, including a locally required Waybar unit and daemon-specific fonts/background workflow. | They are correct for the current v3 deployment but stale as migration-target documentation because Quattro replaces those components with Quickshell. Rewrite/remove only in the implementation phase after the shell passes acceptance. [W1–W3, L5] |
| `/home/glats/.nixos/hosts/t14/omarchy-config.nix:30–33, 98–100` | t14 documents standalone iwd as the selected Omarchy Wi-Fi model and describes a greeter Waybar layout indicator. | Quattro’s selected design is NetworkManager and its shell bar, so the v4 migration documentation must describe the new ownership while retaining the greeter mechanism only if still needed. [W1, W7, W9, L5] |

## Contradictions, Uncertainty, and Freshness

- The local fork’s v3 documentation calls upstream `basecamp/omarchy`, while current admitted GitHub sources identify `omacom/omarchy`; this is a confirmed documentation staleness issue, not an implementation contradiction.
- Upstream’s Quattro lock PAM files refer to Arch PAM includes. This research validates the required behavior and service separation, but not an exact NixOS PAM translation; that mapping remains an implementation-time verification gate.
- Quattro supports an extensible plugin ecosystem, but the approved migration scope does not select any third-party plugin. Plugin parity is deferred because the shell documentation explicitly treats plugin code as unsandboxed.
- The release evidence makes the v3 daemon replacements current as of 2026-09-14. Exact upstream file paths and plugin composition may change after the recorded Quattro commit; implementation should re-check the pinned source revision before coding.

## Non-Authoritative Product Choices

The `port now`, `retain as-is`, `defer`, and `explicitly exclude` rows are research recommendations for the approved scope. Product confirmation remains with the orchestrator/change owner; no implementation permission is implied by this artifact.

## Pre-Proposal Readiness

```yaml
schema: gentle-ai.sdd-preproposal/v1
revision: 2
research:
  selected: true
  request: retained
  classes: [documentation, open-web]
  admission: admitted
  outcome: done
  evidence_reference: openspec/changes/migrate-t14-omarchy-quattro-v4/research.md
product_decisions: pending
proposal_ready: false
```
