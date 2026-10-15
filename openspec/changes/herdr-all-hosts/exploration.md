# Exploration: herdr-all-hosts

Implement Herdr (https://herdr.dev) across ALL hosts. SDD exploration only — no
implementation edits.

## Research sources (all consulted before repo analysis)

- **Context7** — `/herdrdev/herdr` (resolved), `/websites/herdr_dev`. Install,
  persistence/remote, connecting-machines, and Nix docs indexed. No quota block
  this run (unlike the 2026-09-24 evaluation).
- **GitHub** (`get_me` first → `glats`/Juan Cuzmar) — `herdrdev/herdr` (latest
  release **v0.9.3**, 2026-09-29), `herdrdev/herdr-nix` (official prebuilt
  packaging), `NixOS/nixpkgs` `pkgs/by-name/he/herdr/package.nix`,
  `nix-community/home-manager` `modules/programs/herdr.nix`.
- **Exa** — herdr.dev marketing/docs, `herdrdev/herdr-nix` README,
  `tigorlazuardi/herdr-web-tui` (third-party HM module that consumes
  `programs.herdr`).
- **nixos** MCP (`nix_versions`) — nixpkgs `herdr` attribute history.

## What Herdr is (verified)

Herdr is an **agent-aware terminal multiplexer and background runtime** for AI
coding agents: a background server owns real terminal panes, clients
attach/detach/render them, and Herdr detects each agent's lifecycle
(`working`/`blocked`/`done`/`idle`) per pane. It runs the CLIs the user already
has (Claude Code, Codex, Cursor, opencode, Grok…) without wrapping them. A local
socket API + CLI let scripts/agents drive it. Remote attach over SSH
(`herdr --remote <host>`, saved machines) unifies local + remote workspaces.

- **Canonical source:** https://github.com/herdrdev/herdr (Rust, one binary).
- **License:** previously **Apache-2.0** (nixpkgs package.nix for v0.9.1 and
  herdr's own `nix/package.nix` both declare `asl20`). The **official
  `herdr-nix` packaging (v0.9.3) states Herdr is now dual-licensed with an
  **AGPL-3.0-or-later** open-source track** — see `herdr-nix/README.md`
  "Licensing". This is a **material change vs. the 2026-09-24 evaluation**
  (which recorded Apache-2.0) and must be confirmed before a proposal.
- **Current version:** v0.9.3 (stable; `preview-*` pre-releases skipped by
  packaging).
- **Install surfaces:** `curl install.sh`; Homebrew; mise; Nix source flake
  (`nix run github:herdrdev/herdr/vX.Y.Z`, builds Rust+Zig, **no binary cache**);
  **`herdrdev/herdr-nix`** (official, prebuilt release binaries, hash-verified,
  **public Cachix `herdr` cache**, supported on 4 systems).
- **nixpkgs:** `herdr` package exists in **nixos-unstable only** (v0.9.1). It is
  **NOT in the pinned `nixos-26.05`** (verified: `nix eval ... pkgs.herdr` →
  "attribute 'herdr' missing"; the repo's `flake.lock` pins nixpkgs to
  `nixos-26.05` rev `4382ed2b…`).
- **Home Manager:** `programs.herdr` module exists in home-manager (added
  2026-06-27; the repo pins `home-manager/master`). It exposes `enable`,
  `package` (defaults to `pkgs.herdr`), and `settings` (TOML written to
  `$XDG_CONFIG_HOME/herdr/config.toml`, with `server reload-config` onChange).

## Platform matrix

| Host | System | Arch | User | Role | Herdr support |
|------|--------|------|------|------|---------------|
| rog | NixOS + standalone HM | x86_64-linux | glats | desktop, XRDP/MATE, NVIDIA, home server | ✅ binary `herdr-linux-x86_64` |
| thinkcentre | NixOS + standalone HM | x86_64-linux | glats | headless, XRDP | ✅ same binary (SSH/remote attach is the main path) |
| t14 | NixOS + standalone HM | x86_64-linux | glats | laptop, Omarchy/Hyprland | ✅ same binary |
| macm5 | nix-darwin + HM | aarch64-darwin | juan (jcuzmar) | Apple Silicon | ✅ binary `herdr-macos-aarch64` |

All four hosts are supported. The prior evaluation ("scoped to Linux") is stale:
Herdfr ships `herdr-macos-aarch64` and the `herdr-nix` flake covers
`x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`.

## Prior art in this repo

`openspec/changes/evaluate-external-ai-tooling-additions-and-replacements/`
(2026-09-24) evaluated Herdr and **deferred** it as "redundant with tmux +
openfang". This new change **reverses that deferral** on the user's explicit
instruction. Differences since then: (1) Herdr now has a first-class
Home-Manager module + official prebuilt-Nix packaging + Cachix cache; (2) license
appears to have moved to AGPL-3.0 (dual); (3) the user has now explicitly
requested all-hosts adoption.

Existing repo context that Herdr overlaps or interacts with:
- `shared/tmux.nix` — heavy tmux config (TPM + resurrect + continuum +
  vim-tmux-navigator). Herdr is a *second* multiplexer; coexists but overlaps.
- `linux/home/openfang.nix` — always-on Telegram agent (systemd user service).
- `shared/claude-code.nix`, `shared/opencode.nix` — harnesses Herdr would host.

## Current State (repository evidence)

- Persistence mode: **hybrid** (`openspec/config.yaml`: `project: nixos-hosts`,
  `mode: hybrid`).
- Hosts are flat: `hosts/<host>/default.nix` (NixOS/darwin) +
  `hosts/<host>/home/default.nix` (standalone HM list). Shared HM modules live in
  `shared/`, registered in `linux/home/shared-modules.nix` (rog/thinkcentre/t14)
  and `darwin/home/shared-modules.nix` (macm5). t14 filters a few entries out of
  the Linux list (`theme/fontconfig/alacritty/gpg`) but keeps everything else.
- Flake inputs include precedents for wrapping a prebuilt binary from an external
  flake: `claude-code-nix` ("always latest binary"), plus `herdrdev/herdr-nix` is
  the direct analog.
- Overlays (`overlays/linux.nix`, `overlays/darwin.nix`) are the injection point
  for `pkgs.*` overrides; `cachix.nix`/`cachix-settings.nix` manage substituters.
- `pkgs.herdr` does **not** exist in the pinned nixpkgs → the HM module's default
  `package = pkgs.herdr` will fail to evaluate unless the package is provided.

## Affected Areas (for the eventual proposal/spec)

- `flake.nix` — add `herdr-nix` (or `herdrdev/herdr`) input; optionally add its
  Cachix substituter/trusted key to `nixConfig`.
- `overlays/linux.nix` + `overlays/darwin.nix` — expose `pkgs.herdr` so the HM
  module and any profile reference resolve (or point the module at
  `inputs.herdr-nix.packages.${system}.default` directly).
- `shared/herdr.nix` (new) — Home Manager module wrapping `programs.herdr`
  (`enable = true`, `settings`, `package`).
- `linux/home/shared-modules.nix` + `darwin/home/shared-modules.nix` — register
  `shared/herdr.nix` so all four hosts receive it.
- `openspec/specs/` — new delta spec domain (e.g. `herdr-terminal-runtime`) with
  per-host scenarios (config rule: "Tag scenarios with affected host(s)").
- Possibly `cachix-settings.nix`/`cachix.nix` — third-party `herdr` cache trust.

## Approaches

1. **`herdr-nix` flake input + overlay + `programs.herdr` HM module (recommended).**
   Add `inputs.herdr-nix.url = "github:herdrdev/herdr-nix"` (follow its nixpkgs to
   ours), overlay `herdr = inputs.herdr-nix.packages.${system}.default`, then a
   shared `shared/herdr.nix` enabling `programs.herdr` with settings. Pull the
   public `herdr` Cachix cache to avoid any build.
   - Pros: official, hash-pinned (v0.9.3), no Rust/Zig toolchain, all 4 systems,
     mirrors the `claude-code-nix` pattern, declarative config via the existing HM
     module; per-host settings possible.
   - Cons: third-party Cachix trust decision; version bump = `nix flake update
     herdr-nix`; herdr-nix uses `flake-utils` + `nixos-unstable` internally
     (mitigate with `inputs.nixpkgs.follows`).
   - Effort: Low–Medium.

2. **Backport nixpkgs `herdr` package.nix into `pkgs/herdr` (source build).**
   Copy the nixos-unstable derivation (rustPlatform + `zig_0_16` + fetchFromGitHub)
   and call it from an overlay.
   - Pros: no third-party cache; matches the `teams-for-linux`/`afdko` override
     precedent in `overlays/linux.nix`; keeps everything in-repo.
   - Cons: builds Rust+Zig from source (slow, `zig_0_16` must exist in 26.05 —
     **unverified**); every host rebuilds; heavier maintenance of cargoHash/zigDeps
     per bump; still needs the HM module wiring.
   - Effort: Medium–High.

3. **Herdfr source flake input (`herdrdev/herdr`).**
   Add `github:herdrdev/herdr` as input and use its `packages.<system>.herdr`.
   - Pros: upstream-official.
   - Cons: builds Rust+Zig from source on every eval, **no binary cache**, pins
     `nixos-unstable` + `rust-overlay` internally; worst of both worlds for this
     repo's 26.05 boundary.
   - Effort: Medium.

4. **Inline prebuilt-binary derivation (re-implement `herdr-nix` locally).**
   A local `pkgs/herdr/default.nix` doing `fetchurl` + `autoPatchelfHook` with
   pinned version+hashes.
   - Pros: no external flake input or Cachix; full control.
   - Cons: re-implements the official packaging repo; the repo convention prefers
     `herdr-nix` (a maintained upstream) over duplicating it; version bump is
     manual hash churn.
   - Effort: Low–Medium.

## Recommendation

**Approach 1** — `herdr-nix` flake input + overlay exposing `pkgs.herdr` + the
existing Home-Manager `programs.herdr` module wrapped in a new `shared/herdr.nix`
registered in both shared-module lists (covers all four hosts, including t14's
filtered list and macm5's Darwin list). This is the minimal, idiomatic, and
officially-supported path; it matches the repo's `claude-code-nix` precedent and
avoids source builds on a repo pinned to nixos-26.05.

Keep Herdr as an **addition** (coexists with tmux/openfang); do not rip out the
existing tmux config in the same change. Scope is package + declarative config
(`programs.herdr`), not a systemd user service (Herdr starts its background server
on first `herdr` run; no NixOS/HM service module exists upstream yet — a managed
`herdr server` unit would be a separate follow-up).

## Security / update risks

- **License change:** nixpkgs/herdr-flake still say Apache-2.0; official packaging
  now says **AGPL-3.0-or-later (dual-licensed)**. Must be confirmed from the
  current `herdrdev/herdr/LICENSE` before proposal. AGPL is fine for personal use
  of the binary, but the repo tracks licenses carefully (cf. joypixels acceptance).
- **Third-party Cachix trust:** pulling `herdr.cachix.org` (key
  `herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=`) adds a
  substituter to the build. Avoid it entirely by building the (tiny, binary-only)
  derivation locally, or accept it explicitly in `nixConfig`.
- **Network ingress:** `herdr --remote` / saved machines open an SSH-attach
  surface; saved profiles store **no** secrets (opaque IDs only, auth stays with
  OpenSSH). On headless thinkcentre this is the primary use case.
- **Update behavior:** `herdr update` is for Herdr's own installer only; Nix
  installs must update via `nix flake update herdr-nix` (docs are explicit).
  In-app release notification exists; **no analytics telemetry confirmed**, but
  this was not audited source-level.
- **macOS Gatekeeper:** the `herdr-macos-aarch64` binary may be ad-hoc/unsigned;
  potential quarantine prompt on macm5. Verify before claiming macm5 success.
- **Coexistence:** running Herdr alongside the existing tmux config is harmless
  but doubles multiplexer state; decide (in proposal) whether tmux stays default.

## Blockers / questions for the proposal

1. Confirm the **current license** from `herdrdev/herdr/LICENSE` (AGPL-3.0 vs
   Apache-2.0) — the two packaging sources disagree.
2. Confirm the user is OK with a **third-party Cachix** (`herdr`) or prefers a
   local binary-only build (no substituter).
3. Decide whether Herdr should be enabled with **default config only**, or whether
   per-host `programs.herdr.settings` are wanted (e.g. remote machines on
   thinkcentre/rog).
4. Confirm **tmux remains** (addition, not replacement) for this change.
5. Scope boundary: is a managed `herdr server` systemd user service (headless
   thinkcentre auto-start) in scope now, or a separate follow-up change?
6. Version pinning: track `herdr-nix` latest (v0.9.3) via `nix flake update`, or
   pin a specific tag in `flake.lock` and bump manually.

## Ready for Proposal

**Yes — with the blockers above resolved.** The orchestrator should tell the user
that Herdr is adoptable across all four hosts via the official `herdr-nix` +
`programs.herdr` path, that the license needs confirming (AGPL vs Apache), and ask
the Cachix-trust + tmux-coexistence + settings-scope questions before drafting the
proposal.

## Evidence URLs

- https://herdr.dev/ and https://herdr.dev/docs/install/ (Nix/Homebrew install)
- https://github.com/herdrdev/herdr (source; releases → v0.9.3)
- https://github.com/herdrdev/herdr-nix (official prebuilt packaging + Cachix)
- https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/he/herdr/package.nix
- https://github.com/nix-community/home-manager/blob/master/modules/programs/herdr.nix
- https://herdr.dev/docs/persistence-remote/ and https://herdr.dev/docs/connecting-machines/
