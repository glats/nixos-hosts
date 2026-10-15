# Exploration: herdr-multi-host

Implement Herdr (https://herdr.dev/) across ALL hosts. SDD exploration only — no
implementation edits.

> Prior art: an earlier exploration exists under `openspec/changes/herdr-all-hosts/`
> (Engram `#3536`, 2026-10-01). This artifact is a fresh re-exploration under the
> orchestrator-assigned name `herdr-multi-host`, with re-run research (Context7,
> GitHub, Exa, nixos MCP) that materially updates several findings — most
> importantly the license question, which is now resolved.

## Research sources (all consulted before repo analysis)

- **Context7** — `/herdrdev/herdr` (1555 snippets), `/websites/herdr_dev` (860
  snippets), `/websites/deepwiki_herdrdev_herdr`. `query-docs` for install and
  license/pricing/telemetry.
- **GitHub** (`get_me` first → `glats` / Juan Cuzmar, `jcuzmar@protonmail.com`) —
  `herdrdev/herdr` (release **v0.9.3**, LICENSE, README), `herdrdev/herdr-nix`
  (flake.nix, README), `NixOS/nixpkgs` `pkgs/by-name/he/herdr/package.nix`
  (nixos-unstable), `nix-community/home-manager` `modules/programs/herdr.nix`.
- **Exa** — herdr.dev landing/docs, Herdr blog ("joining Y Combinator"), LICENSE,
  agent/automation/remote docs, third-party `DIodide/herdr-telemetry`, remote-attach
  issue threads.
- **nixos** MCP (`nix_versions`) — nixpkgs `herdr` attribute history.

## What Herdr is (verified)

An **agent-aware terminal multiplexer and background runtime**: a single Rust
binary runs a background server that owns real terminal panes; clients
attach/detach/render them; Herdr detects each coding agent's lifecycle
(`working`/`blocked`/`done`/`idle`/`unknown`) per pane and rolls state up through
tabs → workspaces → a sidebar. A CLI + local socket API let scripts/agents drive
it (`pane run`, `agent start`, `agent prompt`, `agent wait`, `agent read`,
`pane wait-output`). Remote attach over SSH (`herdr --remote <host>`, saved
machines) unifies local + remote workspaces. It runs the CLIs already installed
(Claude Code, Codex, Cursor, opencode, Grok, Copilot, Gemini, …) without wrapping
them. Plugins extend panes/workflows.

- **Canonical source:** https://github.com/herdrdev/herdr (one Rust binary, no
  Electron). ~40k stars / ~1M installs / ~1.3k community plugins / 22 agent CLIs.
- **Latest release:** **v0.9.3** (2026-09-29), stable. Assets:
  `herdr-linux-x86_64`, `herdr-linux-aarch64`, `herdr-macos-aarch64`,
  `herdr-macos-x86_64`, `herdr-windows-x86_64.zip`.

## Licensing / pricing / telemetry / security (verified)

- **License: Apache-2.0 — CONFIRMED.** `herdrdev/herdr/LICENSE` at master is the
  full Apache-2.0 text; nixpkgs `package.nix` declares `asl20`; NixHub reports
  "Apache-2.0". The blog post "Herdr is joining Y Combinator. The runtime stays
  open." (2026-08-06) states explicitly: *"The runtime … stays free. Apache-2.0.
  That's why I recently switched it from AGPL to Apache."* This resolves the prior
  exploration's open question. **Note:** `herdrdev/herdr-nix/README.md` still says
  the binaries are "AGPL-3.0-or-later" — that claim is stale and should be ignored;
  the `herdr-nix` *packaging* code itself is MIT.
- **Pricing: free runtime, no paid tier.** YC-backed. Monetization is sponsorship +
  enterprise/partnership (`hey@herdr.dev`), and a future "spaces" product; the
  runtime you run stays free and Apache-2.0.
- **Telemetry: no analytics telemetry confirmed in the core product** (not audited
  source-level — treat as "none found, unverified"). Two *background network*
  behaviors exist and are configurable: (1) automatic update checks with an
  in-app notification, and (2) background fetch of remote **agent-manifest** rule
  updates from herdr.dev (disable via `[update] manifest_check = false`). A
  separate third-party opt-in plugin (`DIodide/herdr-telemetry`) streams
  workspace/agent events to an endpoint *you* control — it is not part of Herdr.
- **Security: no CVEs found.** Remote attach authenticates via normal OpenSSH;
  saved machine profiles store opaque IDs, not credentials. Known issues are UX
  bugs, not vulnerabilities: #1034 (SSH-passphrase Debug-format error), #888/#1050
  (repeated password prompt / keyboard-interactive 2FA), #966 (macOS Keychain
  unavailable from SSH/background-launched server), #4100 (macOS logout loses
  user/DNS). Windows is not supported as a *remote host*; Linux/macOS hosts on
  x86_64 and aarch64 are. macOS binary is likely ad-hoc/unsigned → possible
  Gatekeeper quarantine on first run (unverified).

## Nix package availability and install/service constraints

- **nixpkgs:** `pkgs.herdr` exists in **nixos-unstable only** (v0.9.1, source
  build: rustPlatform + `zig_0_16` + `libghostty-vt` vendored deps). It is **NOT
  in the pinned `nixos-26.05`** (prior exploration verified `nix eval pkgs.herdr`
  → attribute missing; NixHub lists 0.7.0–0.8.2 on unstable commits).
- **Home Manager:** `programs.herdr` module exists (repo pins `home-manager/master`,
  so it is available). Options: `enable`, `package` (`mkPackageOption pkgs "herdr"
  { nullable = true }` → resolves to `pkgs.herdr` if present, else `null`),
  `settings` (TOML → `$XDG_CONFIG_HOME/herdr/config.toml`, with
  `onChange = "herdr server reload-config || true"`). On nixos-26.05 `pkgs.herdr`
  is missing, so the package MUST be provided via overlay/flake or the module
  leaves the binary to `$PATH`.
- **Official prebuilt packaging — `herdrdev/herdr-nix`:** fetches Herdr's own
  prebuilt release binaries (hash-verified, no compilation, no Rust/Zig toolchain)
  for `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`. Exposes
  `packages.<system>.default` and `apps.<system>.default`. Publishes a public
  Cachix cache `herdr` (key
  `herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=`). Internally it
  pins `nixpkgs/nixos-unstable` + `flake-utils` (mitigate with `follows`). Version
  is pinned in its `package.nix`; bump via `nix flake update herdr-nix`.
- **Other install surfaces:** `curl -fsSL https://herdr.dev/install.sh | sh`
  (forbidden in-repo by tool-adoption rules), Homebrew `brew install herdr`, and
  the source flake `nix run github:herdrdev/herdr/vX.Y.Z` (builds Rust+Zig, no
  binary cache).
- **Service/daemon:** Herdr starts its background server on first `herdr` run; no
  NixOS/HM service module exists upstream. A managed auto-start unit for headless
  hosts would be a separate follow-up (mirrors the `openfang` systemd-user-service
  pattern in `linux/home/openfang.nix`).

## Platform matrix (all four hosts supported)

| Host | System | Arch | User | Herdr asset | Notes |
|------|--------|------|------|-------------|-------|
| rog | NixOS + standalone HM | x86_64-linux | glats | `herdr-linux-x86_64` | desktop/MATE/XRDP/NVIDIA + home server; always-on attach target |
| thinkcentre | NixOS + standalone HM | x86_64-linux | glats | `herdr-linux-x86_64` | headless/XRDP; remote-attach is the primary path |
| t14 | NixOS + standalone HM | x86_64-linux | glats | `herdr-linux-x86_64` | laptop/Omarchy/Hyprland; detach across lid/network drops |
| macm5 | nix-darwin + integrated HM | aarch64-darwin | juan (jcuzmar) | `herdr-macos-aarch64` | Apple Silicon; Keychain/Gatekeeper caveats |

## Current State (repository evidence)

- Persistence mode: **hybrid** (`openspec/config.yaml`: `project: nixos-hosts`,
  `mode: hybrid`).
- Shared HM module lists are the single source of truth:
  `linux/home/shared-modules.nix` (rog/thinkcentre/t14 base) and
  `darwin/home/shared-modules.nix` (macm5 base, imported by
  `darwin/home/default.nix` → `home-manager.users.juan.imports`). t14 filters
  `theme/fontconfig/alacritty/gpg` out of the Linux list but keeps everything else.
- Overlays (`overlays/linux.nix`, `overlays/darwin.nix`) are the injection point
  for `pkgs.*`; `claude-code` is the precedent for an external-flake prebuilt
  binary (via `lib/packages.nix` + overlay `inherit`).
- Substituters live in `shared/cachix-settings.nix`, consumed by
  `shared/cachix.nix` (Linux `nix.settings`) and `darwin/system/cachix.nix`
  (Darwin `determinateNix.customSettings`). There is **no `nixConfig` block** in
  `flake.nix`.
- `pkgs.herdr` does not exist in the pinned nixpkgs → the HM module's
  `package` option resolves to `null` unless an overlay/flake provides it.

## Approaches

1. **`herdr-nix` flake input + overlay `pkgs.herdr` + `programs.herdr` HM module (recommended).**
   Add `inputs.herdr-nix.url = "github:herdrdev/herdr-nix"` with
   `inputs.nixpkgs.follows = "nixpkgs"`; overlay
   `herdr = inputs.herdr-nix.packages.${final.stdenv.hostPlatform.system}.default`
   in both overlays; add a `shared/herdr.nix` enabling `programs.herdr`
   (`package = pkgs.herdr`; optional per-host `settings`); register it in both
   shared-module lists.
   - Pros: official, hash-pinned prebuilt (v0.9.3), no Rust/Zig toolchain, covers
     all 4 systems, mirrors the `claude-code-nix` precedent, declarative config via
     the existing HM module; per-host settings possible.
   - Cons: third-party flake input (its internal nixpkgs-unstable must be
     `follows`'d); version bump = `nix flake update herdr-nix`; optional Cachix
     trust decision (see Risks).
   - Effort: Low–Medium.

2. **Backport nixpkgs `herdr` package.nix into `pkgs/herdr` (source build).**
   Copy the nixos-unstable derivation (rustPlatform + `zig_0_16`) into an overlay.
   - Pros: no external flake/cache; keeps everything in-repo (matches the
     `teams-for-linux`/`afdko` override precedent).
   - Cons: builds Rust+Zig from source on every host (slow; `zig_0_16` availability
     in 26.05 unverified); heavy `cargoHash`/`zigDeps` maintenance per bump; still
     needs the HM module wiring.
   - Effort: Medium–High.

3. **Herdr source flake input (`herdrdev/herdr`).**
   - Cons: builds Rust+Zig from source with no binary cache; pins nixos-unstable +
     rust-overlay internally. Worst fit for this repo's 26.05 boundary.
   - Effort: Medium.

4. **Inline prebuilt-binary derivation (re-implement `herdr-nix` locally).**
   - Pros: no external flake input; full control.
   - Cons: duplicates an officially-maintained packaging repo; manual hash churn per
     bump.
   - Effort: Low–Medium.

## Recommendation

**Approach 1** — `herdr-nix` flake input + overlay exposing `pkgs.herdr` + a new
`shared/herdr.nix` wrapping the existing `programs.herdr` module, registered in
both `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix` (covers
rog, thinkcentre, t14, and macm5 through their respective lists). This is the
minimal, idiomatic, officially-supported path; it matches the `claude-code-nix`
precedent and avoids source builds on a repo pinned to nixos-26.05. The herdr-nix
"build" is a hash-verified download of a prebuilt binary, so the Cachix substituter
is an *optional* optimization — prefer skipping it to avoid adding a third-party
trust surface (see Risks).

Keep Herdr as an **addition** (coexists with tmux/openfang); do not rip out the
existing `shared/tmux.nix` config in the same change. Scope = package +
declarative `programs.herdr` config, not a managed `herdr server` systemd unit
(that is a separate follow-up for headless thinkcentre/rog auto-start).

## Affected Areas (for the eventual proposal/spec)

- `flake.nix` — add `inputs.herdr-nix` (`inputs.nixpkgs.follows = "nixpkgs"`).
- `overlays/linux.nix` + `overlays/darwin.nix` — expose `pkgs.herdr` from the
  flake input.
- `shared/herdr.nix` (new) — HM module enabling `programs.herdr` with
  `package = pkgs.herdr` and optional `settings`.
- `linux/home/shared-modules.nix` + `darwin/home/shared-modules.nix` — register
  `../../shared/herdr.nix` so all four hosts receive it.
- `openspec/specs/` — new delta spec domain (e.g. `herdr-terminal-runtime`) with
  per-host scenarios (config rule: "Tag scenarios with affected host(s)").
- Optionally `shared/cachix-settings.nix` — only if the `herdr` Cachix is accepted.

## Risks

- **Stale license claim:** `herdr-nix/README` says "AGPL-3.0-or-later" while the
  authoritative `herdrdev/herdr/LICENSE` and the maintainer's blog are Apache-2.0.
  The proposal should record Apache-2.0 and note the stale README (no action
  needed for personal use).
- **Third-party flake input:** `herdr-nix` internally pins `nixos-unstable`;
  mitigate with `inputs.nixpkgs.follows` so it evaluates against the repo's 26.05.
- **Optional Cachix trust:** adding `herdr.cachix.org` (key
  `herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=`) adds a
  substituter. The herdr-nix derivation is a trivial verified download, so skip
  the cache by default.
- **Network ingress:** `herdr --remote` / saved machines open an SSH-attach surface
  (OpenSSH-auth only; opaque IDs stored). On headless thinkcentre this is the
  primary use case and is expected.
- **Background network:** update checks + remote agent-manifest fetches are on by
  default; document `[update] manifest_check = false` if a quiet/air-gapped host is
  desired.
- **macOS:** possible Gatekeeper quarantine (unsigned binary) and Keychain
  availability from background/SSH-launched servers on macm5.
- **Coexistence:** running alongside tmux doubles multiplexer state; decide in the
  proposal whether tmux stays the default (recommended: yes, addition not
  replacement).

## Unresolved decisions (for the proposal)

1. Confirm **Apache-2.0** is acceptable (it is permissive; no joypixels-style
   acceptance gate needed) and note the stale `herdr-nix` README claim.
2. **Cachix trust:** accept the `herdr` cache or build locally (recommend: build
   locally, skip the substituter).
3. **Default config vs per-host settings:** e.g. saved remote machines on
   rog/thinkcentre, or leave `settings = {}` and configure at runtime.
4. **tmux coexistence:** keep tmux default (addition, not replacement).
5. **Scope boundary:** managed `herdr server` auto-start for headless thinkcentre is
   a separate follow-up change, not this one.
6. **Version pinning:** track `herdr-nix` latest (v0.9.3) via `nix flake update`,
   or pin a specific tag in `flake.lock`.

## Ready for Proposal

**Yes — with the decisions above resolved.** Herdr is adoptable across all four
hosts via the official `herdr-nix` prebuilt + `programs.herdr` path. The license
question is now settled (Apache-2.0). The orchestrator should ask the user about
Cachix trust, settings scope, and tmux coexistence before drafting the proposal.

## Evidence URLs

- https://herdr.dev/ and https://herdr.dev/docs/install/ (Nix/Homebrew install)
- https://herdr.dev/docs/agents/ (agent detection + supported-agent table)
- https://herdr.dev/docs/agent-automation/ (socket API / CLI automation)
- https://herdr.dev/docs/persistence-remote/ (remote attach over SSH)
- https://herdr.dev/blog/herdr-is-joining-y-combinator/ (Apache-2.0 switch, free runtime)
- https://github.com/herdrdev/herdr (source; LICENSE = Apache-2.0; releases → v0.9.3)
- https://github.com/herdrdev/herdr-nix (official prebuilt packaging + Cachix)
- https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/he/herdr/package.nix
- https://github.com/nix-community/home-manager/blob/master/modules/programs/herdr.nix
- https://github.com/herdrdev/herdr/issues/1034 (SSH-passphrase attach error)
- https://github.com/DIodide/herdr-telemetry (opt-in third-party telemetry plugin)
