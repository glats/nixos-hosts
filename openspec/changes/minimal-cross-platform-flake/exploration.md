## Exploration: minimal-cross-platform-flake — OpenAI Codex CLI (re-exploration)

### Current State

The user's `nixos-hosts` repo at `/home/glats/.nixos` is a mature multi-host Nix flakes configuration spanning NixOS (rog, thinkcentre, t14) and nix-darwin (macm5). It uses `lib/mkHost.nix` and `lib/mkDarwinHost.nix` builders, Determinate Nix on macOS (`inputs.determinate.darwinModules.default`, `nix.enable = false`), sops-nix, omarchy-nix, and extensive `specialArgs` wiring. This complexity is NOT appropriate for the target minimal flake, but specific patterns are extractable: the kmscon NixOS module (`services.kmscon.enable = true`), the flat host-import convention, and the `darwinConfigurations` + `nixosConfigurations` output shape.

The task is a brand-new, separate Git repo with one `flake.nix` configuring two systems: Apple Silicon macOS (aarch64-darwin) via nix-darwin + Determinate Nix, and x86_64-linux NixOS with kmscon. Home Manager is in scope as integrated modules. Target is minimal, robust, independent — no sops, no omarchy, no flake-parts.

This re-exploration adds **OpenAI Codex CLI to both hosts** and corrects the previous kmscon analysis.

### Primary Focus: OpenAI Codex CLI on both hosts

#### `pkgs.codex` availability (verified against nixos-26.05)

`pkgs.codex` exists and is correct in `nixos-26.05`:

- `pkgs/by-name/co/codex/package.nix`, version `0.146.0` (the Rust rewrite, tag `rust-v0.146.0`), built with `rustPlatform.buildRustPackage`.
- `meta.platforms = lib.platforms.unix` → builds on **x86_64-linux and aarch64-darwin**.
- aarch64-darwin is explicitly handled: `NIX_CFLAGS_LINK = "-fuse-ld=${ld64.lld}"` with an inline comment ("nixpkgs' classic open-source ld64 fails to insert ARM64 branch thunks"). Strong evidence Darwin/Apple-Silicon is a supported build target.
- Builds `codex-cli` **and** its out-of-process companion `codex-code-mode-host`; `postFixup` wraps `codex` with `ripgrep` (all platforms) and `bubblewrap` (Linux only).
- Heavy dependency: `librusty_v8` (V8 runtime) via `RUSTY_V8_ARCHIVE`. Build is heavy but normally served from `cache.nixos.org`.
- `meta.mainProgram = "codex"`. `installShellCompletions` ships bash/fish/zsh completions.

Conclusion: `pkgs.codex` is the correct, source-built package for both target systems. There is also a name-collision package `codex` 0.6.0.0 ("ctags file generator for cabal projects") on `search.nixos.org`, but the `by-name` `codex` (agent CLI) is the one `pkgs.codex` resolves to. Do NOT use `@openai/codex` (npm) or the Homebrew cask — the Nix package is declarative and per-system.

#### Installation method (recommended)

- Use `pkgs.codex` from nixpkgs only. No npm, no Homebrew, no third-party `sadjow/codex-cli-nix` flake.
- Place it in the shared Home Manager module as `home.packages = [ pkgs.codex ]`, because auth and config are per-user (`~/.codex/`). Both hosts import the shared home module; `pkgs` resolves per-system (`x86_64-linux` / `aarch64-darwin`), so one line covers both.

#### Authentication (official OpenAI docs)

Auth is interactive and MUST NOT be baked into the flake. Document it in `POST_INSTALL.md`:

- `codex login` — default ChatGPT browser OAuth flow.
- `codex login --device-auth` — device-code flow; the correct path on the headless kmscon console where a browser UI is awkward. Requires enabling device-code login in ChatGPT security/workspace settings.
- `printenv OPENAI_API_KEY | codex login --with-api-key` — API-key auth via stdin.
- Config lives at `~/.codex/config.toml`. Relevant keys: `cli_auth_credentials_store` (`file` | `keyring` | `auto` | `ephemeral`) and `forced_login_method` (`chatgpt` | `api`). Credentials cached in `~/.codex/auth.json` (or OS keychain).

#### Terminal requirements — macOS host (aarch64-darwin)

Terminal.app / iTerm2 / Ghostty are truecolor-capable and need no special config. No action beyond installing `pkgs.codex`.

#### Terminal requirements — kmscon host (corrected analysis)

Grounding (all source-backed):

- kmscon in `nixos-26.05` is version **9.3.5** (`pkgs/by-name/km/kmscon/package.nix`), built on **libtsm**. libtsm's README states: "TSM ... keeps compatibility as close to xterm as possible. This is why the TERM variable can be set to xterm-color256 with any TSM based terminal emulator." kmscon's own man page lists `--term` default as **`xterm-256color`**.
- kmscon is **256-color**, NOT truecolor (24-bit). There is no truecolor support in libtsm/kmscon (libtsm targets xterm-256color compatibility; the kmscon config `palette` exposes a 16-slot mapping, but libtsm parses 256-color SGR).
- Codex color detection is `supports-color` reading **env vars only** (`TERM`, `COLORTERM`) — it does NOT fall back to terminfo (`codex-rs/tui/src/terminal_palette.rs`, and issue #23677 confirms truecolor is not detected from terminfo alone without `COLORTERM`).
- Forcing `COLORTERM=truecolor` on a non-24-bit terminal makes Codex emit 24-bit SGR (`ESC[38;2;...m`) the terminal mis-parses, producing broken diff rendering — the exact failure in issue #15416 (Terminal.app reports `xterm-256color` but can't do truecolor, and diffs render as "faint white over green").

Therefore, for kmscon:

1. **Keep `TERM=xterm-256color`** (kmscon's honest default, matching its 256-color capability). Do NOT override to `xterm-256color`→`xterm` or `linux` — 256-color is correct here.
2. **Do NOT set `COLORTERM` (and never `truecolor`)** anywhere (not in kmscon config, not in shell profiles). With `xterm-256color` and no `COLORTERM`, Codex detects ANSI-256 and renders diffs with 256-color indexed backgrounds — readable, correct.
3. **Unicode**: fully supported (unifont/pango). No action; ensure a font is set only if you want a specific face.
4. **Scrollback**: kmscon has a scrollback buffer (configurable `sb-size`). Codex uses the alternate screen by default; optionally add `[tui] alternate_screen = "never"` to `~/.codex/config.toml` to preserve scrollback. Not required for functionality.
5. **Rendering**: `services.kmscon.hwRender = false` (software rendering) avoids GPU/driver issues on unknown hardware.

Correction of the previous exploration's kmscon notes: the claimed renames (`fonts` → `fonts.packages`, `extraConfig` → `config`, `hwRender` → `config.hwaccel`) are **wrong** for `nixos-26.05`. The actual `services.kmscon` options in `nixos-26.05` are: `enable`, `package`, `hwRender`, `fonts` (list of `{ name, package }`), `useXkbConfig`, `term`, `extraConfig`, `extraOptions`. (On `master`, `services.kmscon.fonts` was later removed; `nixos-26.05` still has it. `services.kmscon.autologinUser` is removed in `nixos-26.05` in favor of `services.getty.autologinUser`.)

### Exact Nix configuration to include

Linux host `configuration.nix` — kmscon (Codex-ready):

```nix
services.kmscon = {
  enable = true;
  hwRender = false;      # software rendering, stable on unknown GPUs
  useXkbConfig = true;
  # term is left at its default (xterm-256color) — honest 256-color for
  # libtsm/kmscon. Do NOT set COLORTERM: kmscon is not truecolor, and a false
  # truecolor signal makes Codex emit 24-bit SGR that renders incorrectly.
  # (Optional) fonts = [ { name = "..."; package = pkgs.some-font; } ];
};
```

Shared Home Manager module (both hosts) — Codex:

```nix
{ pkgs, ... }:
{
  home.packages = [
    pkgs.codex   # OpenAI Codex CLI (Rust); aarch64-darwin + x86_64-linux
  ];
  # Optional: programs.<shell>.initExtra for a CODEX_HOME override, if desired.
}
```

No `environment.systemPackages = [ pkgs.codex ]` at the NixOS level: auth/config are per-user (`~/.codex`), so `home.packages` is the correct placement and works identically through nix-darwin Home Manager on macOS.

### Affected Areas

- **NEW** `flake.nix` — inputs (nixpkgs, nix-darwin, home-manager, determinate), `nixosConfigurations`, `darwinConfigurations`, `homeConfigurations`, formatter
- **NEW** `hosts/<linux-hostname>/configuration.nix` — bootloader, networking, **kmscon (as above)**, user, Home Manager wiring
- **NEW** `hosts/<linux-hostname>/hardware-configuration.nix` — auto-generated (first install)
- **NEW** `hosts/<mac-hostname>/configuration.nix` — `nix.enable = false`, Determinate Nix, user, Home Manager wiring
- **NEW** `home/` — shared Home Manager modules (shell, git, packages incl. **`pkgs.codex`**, tmux) imported by both hosts
- **NEW** `POST_INSTALL.md` — macOS (Determinate install, darwin-rebuild bootstrap) + Linux (NixOS ISO, partition, nixos-generate-config, nixos-install) **plus Codex login steps (`codex login --device-auth` on the kmscon host, `codex login` on macOS, or `--with-api-key`)**
- **NEW** `PARTITIONING.md` — Linux AMD64 partitioning values

### Approaches

1. **Single flat flake.nix with inline host configs** — no builders, each host module listed directly.

   - Pros: minimal mental model, matches official nix-darwin/NixOS manual examples
   - Cons: does not scale past 3-4 hosts
   - Effort: Low

2. **Single flake.nix with simple mkHost/mkDarwinHost builders** — extract ~15-line wrappers around `nixosSystem`/`darwinSystem`.

   - Pros: clean host-add story, avoids repetition
   - Cons: one indirection layer
   - Effort: Low-Medium

3. **Flake-parts module system** — auto-discovery, perSystem.

   - Pros: scales
   - Cons: flake-parts dependency, overkill for 2 hosts, violates "very simple"
   - Effort: Medium-High

### Recommendation

**Approach 1 (single flat flake.nix)** for the deliverable, with Codex placed in the shared Home Manager module as `home.packages = [ pkgs.codex ]`. One line covers both hosts because `pkgs.codex` supports `x86_64-linux` and `aarch64-darwin` via `lib.platforms.unix`.

For the kmscon host, enable kmscon with `hwRender = false` and **no truecolor/COLORTERM override** — the default `xterm-256color` TERM is honest and gives Codex readable ANSI-256 diff rendering. On macOS, no terminal tuning is required.

### Confirmed Decisions & Defaults (recorded)

- **Destination**: `/home/glats/minimal-nix` (new repo).
- **Username**: `claudio` on BOTH hosts.
- **Hostnames** (unspecified; concise robust defaults chosen per user authorization to auto-continue):
  - Linux NixOS (x86_64-linux): `minimal-linux`
  - macOS (aarch64-darwin): `minimal-mac`
  - These are recorded as concrete defaults but remain `sed`-replaceable placeholders in the flake; the docs MUST mention both the default and how to change them.
- **Codex package**: `pkgs.codex` (nixpkgs `nixos-26.05`), via Home Manager.
- **Auth**: interactive, documented in `POST_INSTALL.md`; device-auth or `--with-api-key` for the kmscon host.

### Risks

- `pkgs.codex` depends on `librusty_v8` (V8) — heavy build if not in the binary cache; ensure `cache.nixos.org` is reachable on first build.
- kmscon is 256-color, not truecolor: Codex diffs render in ANSI-256 (readable but less subtle). This is a terminal-capability limit, not a config bug; do not "fix" it by forcing `COLORTERM=truecolor`.
- nix-darwin `system.stateVersion` varies per release — use `5` for nix-darwin-26.05 (verify at generation time).
- `nixpkgs/nixos-26.05` and `nix-darwin/nix-darwin-26.05` branches must exist; both are already used by the main repo, so this is confirmed available.
- kmscon GPU/hardware-accel issues on unknown hardware — mitigated by `hwRender = false`.

### Ready for Proposal

Yes. All unknowns are now resolved (destination, username, hostnames defaulted, package choice, auth path, terminal behavior). The orchestrator should tell the user: Codex will be added via `pkgs.codex` in Home Manager for both hosts; on the kmscon Linux console Codex runs in 256-color mode (no truecolor, which is correct for kmscon); auth is interactive and documented; the defaults `minimal-linux` / `minimal-mac` and username `claudio` are recorded and remain overridable.
