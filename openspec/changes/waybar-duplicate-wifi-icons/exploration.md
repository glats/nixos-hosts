# Exploration: Waybar duplicate wifi icons (t14, omarchy-nix)

## Current State

The waybar config on the **t14** host (the only host that runs waybar via omarchy) contains **two wifi-related modules** in `modules-right`, both of which are unconditionally active. They query wifi state via two different mechanisms, and on t14 those mechanisms disagree — so the user sees a "disconnected" icon next to a "connected" icon at the same time.

### How waybar is configured in nixos-hosts

- **t14** is the only host that uses waybar. `rog` runs MATE (conky), `thinkcentre` is headless, `mact2` is macOS.
- Waybar is **not** configured by any nixos-hosts module. The only references to "waybar" anywhere in `/home/glats/.nixos` are font/import comments and `omarchy.fonts.waybar` (an omarchy option) in `hosts/t14/home/omarchy.nix:106`.
- Waybar is supplied entirely by the `omarchy-nix` flake input (`flake.nix:19-23`):
  - NixOS module: `inputs.omarchy-nix.nixosModules.default` (wired via `extraModules` in `flake.nix:220`).
  - HM module: `inputs.omarchy-nix.homeManagerModules.default` (imported in `hosts/t14/home/omarchy.nix:43`).
- The omarchy HM `waybar.nix` (`modules/home-manager/waybar.nix:9-14`) is a **static recursive copy** — `source = ../../config/waybar; recursive = true;` deploys the entire upstream `config/waybar/` directory to `~/.config/waybar/`. There is no Nix-side generation of the waybar JSON. The config lives in a plain JSON file inside the omarchy-nix source tree.

### The two wifi modules (smoking gun)

`/nix/store/2ldbjgqxrkv7l0wyychjzfa1g6s1xjl8-source/config/waybar/config` (omarchy-nix at rev `b85fdc8e`, the commit pinned by `flake.lock:1096`):

```jsonc
"modules-right": [
  "group/tray-expander",
  "bluetooth",
  "network",          // ← (A) built-in waybar module, uses NetworkManager D-Bus
  "custom/iwd-wifi",  // ← (B) custom shell module, runs iwctl directly
  "pulseaudio",
  "custom/language",
  "cpu",
  "battery"
]
```

- **(A) `network` block (lines 81-93)** — the stock waybar `network` module. Reads state via NetworkManager's D-Bus API. Shows one of `format-icons` (connected, signal bars), `format-ethernet` (lan), or `format-disconnected` (no NM-managed active connection).
- **(B) `custom/iwd-wifi` block (lines 169-174)** — runs `~/.config/waybar/indicators/iwd-wifi.sh` and reads `iwctl station wlan0 show` directly. The script (lines 1-9 of the indicator file) prints `{"text": " <SSID>"}` when iwd reports a connected station, or `{"text": "󰤮", "tooltip": "WiFi disconnected"}` otherwise.

### Why the two icons disagree on t14

`hosts/t14/default.nix:149` sets `omarchy.wifi.backend = "standalone-iwd"`. The omarchy NixOS module (`modules/nixos/system.nix`) translates that to:

```nix
networkmanager = {
  enable = true;
  wifi.backend = lib.mkIf (cfg.wifi.backend != "standalone-iwd") "iwd";
  unmanaged = lib.mkIf (cfg.wifi.backend == "standalone-iwd") [ "interface-name:wlan0" ];
};
networking.wireless.enable = lib.mkIf (cfg.wifi.backend == "standalone-iwd") (lib.mkForce false);
networking.wireless.iwd.settings = lib.mkIf (cfg.wifi.backend == "standalone-iwd") {
  General.EnableNetworkConfiguration = true;
  Network.NameResolvingService = "systemd";
};
```

So on t14:

- **iwd is the actual WiFi manager** (standalone). It owns `wlan0`, runs DHCP via systemd-resolved.
- **NetworkManager is enabled but explicitly told to ignore `wlan0`** (`unmanaged = [ "interface-name:wlan0" ]`). NM still runs and manages ethernet / Docker / other interfaces, but for `wlan0` it sees no active connection.
- Waybar's built-in `network` module talks to NM, sees no active connection on `wlan0`, falls through to `format-disconnected` (`󰤮`, "Disconnected").
- `custom/iwd-wifi` runs `iwctl` against iwd, sees the live iwd state, reports the real connected SSID.

Result: two icons, opposite states. The `network` icon is permanently "disconnected" (because NM has been told to stay away from wlan0), the `custom/iwd-wifi` icon is the truth.

On a host using the default `nm-iwd` backend, the relationship is reversed but no less broken: NM does own `wlan0`, so `network` works correctly, and `custom/iwd-wifi` permanently reports "disconnected" because iwctl doesn't see the connection (NM holds it inside its own iwd D-Bus backend, which `iwctl` reads differently). The previous change's `iwd-wifi-queda-en-upstream-y-no-per-host-como-esta-ahora/proposal.md` explicitly accepted this as a v1 trade-off ("Two wifi icons on `nm-iwd` systems" — "Certain — Accepted v1 trade-off; Approach B follow-up deferred"). The follow-up is what this change is asking for.

### Other hosts — confirmed unaffected

- `rog` (`hosts/rog/default.nix:92` has `networkmanager.enable = true`, no waybar) — uses MATE/Cairo-Dock/conky; no waybar anywhere on the host.
- `thinkcentre` (`hosts/thinkcentre/default.nix:45` has `networkmanager.enable = true`, no waybar) — headless, xrdp only.
- `mact2` — macOS, no waybar.
- The only `networkmanager.enable` mentions in the whole tree are the two `default.nix` files above plus the omarchy `system.nix` (which always enables it). No host in nixos-hosts configures waybar at all.

### Cross-references in nixos-hosts (no waybar overrides, no relevant conflicts)

- `flake.nix:19-23` — `omarchy-nix` input pinned to `github:glats/omarchy-nix/main`; rev `b85fdc8e890727a29773d9e37ac9d8079d8cace7` (flake.lock:1078-1105, lastModified 1782772019).
- `flake.nix:211-222` — t14 wires omarchy-nix + nixos-hardware T14 profile via `extraModules`.
- `hosts/t14/home/omarchy.nix:43` — imports `inputs.omarchy-nix.homeManagerModules.default`.
- `hosts/t14/home/omarchy.nix:106` — `omarchy.fonts.waybar = lib.mkForce "Source Sans 3 Semibold";` (font override only; does not touch modules).
- `hosts/t14/home/default.nix` — no waybar-related content. The previous iwd-wifi per-host block (lines 58-80) was deleted in commit `83593b0` (Jun 28 2026) when the indicator moved upstream.
- `openspec/changes/iwd-wifi-queda-en-upstream-y-no-per-host-como-esta-ahora/` — the prior change folder with `proposal.md` + `design.md`. Contains the explicit "accepted v1 trade-off" note. No `specs/` or `tasks.md` (change was applied without spec/tasks; not archived because the work was completed but the trade-off remained).

## Affected Areas

- `omarchy-nix` repo, `config/waybar/config` (modules-right array + two JSON blocks) — this is where the actual fix must land; nixos-hosts only consumes the file.
- `omarchy-nix` repo, `modules/home-manager/waybar.nix` — the HM module that copies the config. The static-copy pattern is preserved (per the prior change's design); no module changes required.
- `omarchy-nix` repo, `config/waybar/indicators/iwd-wifi.sh` — the script kept; the fix is to make sure only one of the two wifi modules is active.
- `omarchy-nix` repo, `modules/nixos/system.nix` (NM/iwd wiring) — already exposes `cfg.wifi.backend`; the waybar config needs to read the same option.
- `nixos-hosts` repo, `flake.lock` — must be re-pinned to the new omarchy-nix commit (`nix flake update omarchy-nix`).
- `nixos-hosts` repo, `hosts/t14/default.nix:149` — already sets `omarchy.wifi.backend = "standalone-iwd"`; no change required (the fix consumes the option, it does not set it).
- (read-only) `nixos-hosts/openspec/changes/iwd-wifi-queda-en-upstream-y-no-per-host-como-esta-ahora/{proposal,design}.md` — historical record of the v1 trade-off; useful as prior-art reference.

## Approaches

### 1. **Approach A: Make the waybar config Nix-generated and `wifi.backend`-conditional** *(recommended)*

Convert `omarchy-nix/config/waybar/config` from a static JSON file to a Nix expression (e.g. `pkgs.writeText "waybar-config.json" (builtins.toJSON cfg)`) and add the `modules-right` entry + block from a branch on `cfg.wifi.backend` in `modules/home-manager/waybar.nix`:

- `wifi.backend = "nm-iwd"` (default) → emit `network` (built-in).
- `wifi.backend = "standalone-iwd"` (t14) → emit `custom/iwd-wifi` (the iwctl script), do not emit `network`.

- Pros: Eliminates the duplicate permanently on every host. Honors the existing per-backend design (NM for one, iwd for the other). Single source of truth (the option is already in `config.nix`). The previous change's design.md already noted the file as a static copy because "Nix's JSON encoding strips the U+E900 omarchy icon character" — that risk is bounded: the static copy only loses the literal U+E900 codepoint; `cfg.wifi.backend` is ASCII and does not need that character. The omarchy logo glyph itself lives in `custom/omarchy` (line 54) and the static copy can keep that block; only the wifi entries move to generated form, or the whole file is generated with a placeholder for the omarchy icon byte. Need to test what happens to the `custom/omarchy` U+E900 codepoint when the whole JSON is generated — the prior design rejected whole-file generation for exactly that reason.
- Cons: Mixes two deployment styles inside one config file (static for the omarchy-icon block, generated for the wifi blocks) is awkward. If we go whole-file Nix-generated, we need a workaround for the U+E900 stripping. Higher effort and cross-repo coordination (omarchy-nix + flake lock bump).
- Effort: **Medium**.

### 2. **Approach B: Always show `custom/iwd-wifi`; remove the built-in `network` module entirely** *(simple)*

Since the iwctl script can also detect the "no interface" / "iwd not running" case (returns disconnected-icon JSON), drop the built-in `network` from `modules-right` and the corresponding JSON block, and rely on the script for both backends. The script would need a small adjustment to handle the `nm-iwd` case (iwctl does see the SSID even when NM is the iwd netconfig agent, so it may already work; needs verification).

- Pros: One wifi icon, always. Single deployment path. Simpler than Approach A. No Nix-generation of the config file required.
- Cons: The built-in `network` module shows signal-strength bars (the `format-icons` array 󰤯/󰤟/󰤢/󰤥/󰤨), tooltip with frequency, and click-to-launch-wifi via NM. The iwctl script only shows the SSID. Loses signal-strength granularity. Also, the script's hard-coded `wlan0` (`indicators/iwd-wifi.sh:3`) means it will silently mis-report on hosts with a renamed interface. Higher risk for `nm-iwd` users (impala users on hosts we don't control).
- Effort: **Low**.

### 3. **Approach C: Always show built-in `network`; drop `custom/iwd-wifi`** *(wrong for t14)*

Just remove the `custom/iwd-wifi` block and the `modules-right` entry. The built-in `network` module is what 99% of waybar setups use.

- Pros: Trivial. One icon, the standard one. No script maintenance.
- Cons: **Breaks t14's standalone-iwd setup** — with `unmanaged = [ "interface-name:wlan0" ]`, the built-in module permanently shows disconnected, and we lose wifi state visibility on t14. This is the direction the user is trying to *escape from*, not adopt.
- Effort: **Trivial** — but unworkable.

### 4. **Approach D: t14 per-host override that removes `network` from modules-right** *(per-host opt-out, doesn't fix upstream)*

Add a `xdg.configFile."waybar/config-overrides.json"` (or similar) in `hosts/t14/home/default.nix` that drops the `network` block. Waybar only reads one config file, so this is essentially: deploy a per-host modified copy of the omarchy-nix waybar config.

- Pros: Localized change in nixos-hosts only. No cross-repo coordination. Reversible.
- Cons: Forks the waybar config per-host. Re-implements the static-copy mechanism from `waybar.nix:9-14` for this one file. Future omarchy-nix waybar changes (new modules, restyling) won't reach t14 unless the per-host file is also updated. Maintenance debt.
- Effort: **Low–Medium**.

## Recommendation

**Approach A** is the correct long-term fix because it eliminates the duplicate at the source (the omarchy-nix waybar config) and respects the existing `omarchy.wifi.backend` design split. The cost is a small refactor in `omarchy-nix` (generate the wifi blocks via Nix; keep the rest static) plus a `nix flake update omarchy-nix` in nixos-hosts.

If the user wants the smallest possible change that still fixes the symptom and is willing to accept a per-host fork, **Approach D** is the pragmatic short-term: keep the omarchy-nix upstream untouched, override the waybar config for t14. Recommend A unless the user explicitly asks for a fast local fix.

Avoid B and C for the reasons above.

## Risks

- **U+E900 omarchy icon stripping** — The prior design.md explicitly rejected whole-file Nix generation because `builtins.toJSON` mangles the U+E900 codepoint used by `custom/omarchy`. Approach A must either (a) generate only the wifi-related entries and merge them into the static file at evaluation time, or (b) generate the whole file with a placeholder byte sequence that the generation step rewrites. Both are workable; need a small experiment.
- **Cross-repo coordination** — omarchy-nix is a separate repo. The fix has to land there first, then `nix flake update omarchy-nix` in nixos-hosts. Two commits, two PRs (or direct-to-main on both, per the prior change's pattern). The user owns both repos so this is administrative friction, not a blocker.
- **Approach D's maintenance debt** — if we go with the per-host fork, every future omarchy-nix waybar change needs a rebase in t14. A short comment in `hosts/t14/home/default.nix` explaining the reason will help but doesn't eliminate the cost.
- **`custom/iwd-wifi` script correctness under `nm-iwd`** — if we go with Approach B (always iwctl), the script currently returns "disconnected" whenever iwctl doesn't see a wlan0 station. On an `nm-iwd` host, iwctl does still see the station (NM's iwd backend is just a D-Bus shim around iwd), so the script may already work — but this needs live verification on an `nm-iwd` host, which we don't have available in this repo.
- **No automated test harness in either repo** (per `openspec/config.yaml:18-20` and the prior design.md testing strategy). Validation is `nix flake check --no-build` + visual confirmation after `nixos-rebuild switch`. The visual confirmation is the load-bearing test.

## Ready for Proposal

**Yes.** The exploration is complete:

- Root cause is identified: `modules-right` in `omarchy-nix/config/waybar/config` contains both `network` (NM-backed) and `custom/iwd-wifi` (iwctl-backed) unconditionally, and on t14 they disagree because t14 uses `omarchy.wifi.backend = "standalone-iwd"` which marks `wlan0` as NM-unmanaged.
- Affected host is identified: **t14 only**.
- Affected files are identified: all in `omarchy-nix` (`config/waybar/config` is the source of truth; `modules/home-manager/waybar.nix` is the deployment; the script is unchanged). nixos-hosts only needs a flake lock bump and no source edits (under Approach A) or a single file edit (under Approach D).
- The prior change `iwd-wifi-queda-en-upstream-y-no-per-host-como-esta-ahora/` is the relevant historical context (v1 trade-off that this change resolves).
- Three viable approaches with clear tradeoffs. Ready for `sdd-propose` to pick one and write the formal proposal.
