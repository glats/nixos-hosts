# SDD Explore: revisar-scripts-bin-nix-switch-mact2

## Executive Summary

Full inventory of 12 scripts in `bin/` (1799 lines total). Only 4 are packaged in `pkgs/nixos-scripts/`. The remaining 8 exist only in `bin/` and are accessible via `PATH`. **Confirmed bug**: `nixos-build` run on mact2 (Darwin) performs a redundant `home-manager switch` AFTER `darwin-rebuild switch`, despite nix-darwin already deploying HM as an integrated module. Six different REPO_ROOT detection patterns found across scripts, and WireGuard scripts share identical preface code.

---

## 1. Full Inventory: bin/ vs pkgs/nixos-scripts/

| # | Script | Lines | Purpose | Packaged? | How Accessed |
|---|--------|-------|---------|-----------|-------------|
| 1 | `nixos-build` | 328 | Build NixOS/Darwin config (the "nix-switch" script) | YES (line 20-21) | `nixos-scripts` pkg + shell alias `nrs`=`nixos-build switch` + shell function `nix-switch()` |
| 2 | `code-work` | 314 | Git worktree management (create/done/abort/list/prune) | YES (line 13-14) | `nixos-scripts` pkg + shell wrapper function |
| 3 | `sync-opencode-remote` | 331 | Sync opencode config to remote PMOS host | NO | `~/.nixos/bin:$PATH` (shell.nix line 61) |
| 4 | `export-mate-config` | 184 | Export MATE dconf to Nix module | YES (line 23-24) | `nixos-scripts` pkg |
| 5 | `sops-rotate-keys` | 154 | Rotate sops-nix age keys | NO | `~/.nixos/bin:$PATH` |
| 6 | `compare-palette` | 141 | Terminal color palette comparison (dev tool) | NO | `~/.nixos/bin:$PATH` |
| 7 | `format-nix` | 108 | Format Nix files with nixfmt | YES (line 17-18) | `nixos-scripts` pkg + referenced in AGENTS.md |
| 8 | `generate-thinkpad-wireguard` | 86 | Generate WG config for ThinkPad + update Nix | NO | `~/.nixos/bin:$PATH` |
| 9 | `remove-wireguard-peer` | 66 | Remove WG peer from secrets + module | NO | `~/.nixos/bin:$PATH` |
| 10 | `add-wireguard-peer` | 51 | Add WG peer (gen PSK, print template) | NO | `~/.nixos/bin:$PATH` |
| 11 | `webcam` | 28 | View webcam with mpv | NO | `~/.nixos/bin:$PATH` |
| 12 | `sops-add-t14` | 8 | Add t14 host key to sops secrets | NO | `~/.nixos/bin:$PATH` |

**Summary**: 4 packaged (934 lines), 8 unpackaged (865 lines). All unpackaged scripts are available because `~/.nixos/bin` is prepended to `PATH` in `home-linux/shell.nix` line 61.

### How scripts are installed per host

| Host | Mechanism | File |
|------|-----------|------|
| rog, thinkcentre, t14 | `home.packages = [ pkgs.nixos-scripts ]` | `home-linux/shell.nix:8` |
| mact2 | `home.packages = [ pkgs.nixos-scripts ]` | `home-darwin/shell.nix:3` |
| Linux (flake app) | `apps.x86_64-linux.nixos-build` | `flake.nix:194-201` |

The `nixos-scripts` derivation is built per-platform via `lib/packages.nix` lines 33 (Linux) and 68 (Darwin), and exposed via overlays (`overlays/linux.nix:10`, `overlays/darwin.nix:30`).

---

## 2. Detailed Analysis of nixos-build (the "nix-switch" script)

### Architecture

The script has three layers:

1. **Platform detection** (lines 21-24): Checks `uname` for Darwin vs Linux.
2. **Tool detection** (lines 50-60): Linux-only: detects `nh` (NixOS helper) and `nom` (nix-output-monitor).
3. **Command dispatch** (lines 124-328): `switch`, `boot`, `test`, `upgrade`, `dry`, `check`, `build`, `safe`.

### Per-host behavior

| Host | Platform | Build Tool | HM Handling |
|------|----------|------------|-------------|
| rog | Linux | `nh os switch` (default) or `sudo nixos-rebuild switch` | Integrated (NixOS module) |
| thinkcentre | Linux | same | Integrated |
| t14 | Linux | same | Integrated (Omarchy) |
| mact2 | Darwin | `sudo darwin-rebuild switch` | **REDUNDANT: separate `home-manager switch` runs after** |

### Shell alias chain

```
nix-switch (shared/shell-aliases.nix:53-55)
  -> nixos-build switch (via shell function)
     -> darwin_build switch (line 129) + home-manager switch (line 132) [on Darwin, the BUG]
```

Also: `nrs` alias = `nixos-build switch` (home-linux/shell.nix:45).

---

## 3. CONFIRMED: mact2 Double HM Activation Bug

### Root Cause

In `nixos-build` (bin/nixos-build), three commands perform redundant HM activation on Darwin:

**`switch` (lines 127-132):**
```bash
if $IS_DARWIN; then
  echo "> Building Darwin configuration (switch)..."
  darwin_build switch                    # <-- runs: sudo darwin-rebuild switch
  echo ""
  echo "> Switching home-manager..."
  home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"  # <-- REDUNDANT!
```

**`upgrade` (lines 180-183):** Same pattern.
**`safe` (lines 294-302):** Same pattern.

### Why it's redundant

`darwin-rebuild switch` already deploys HM because:

1. `darwin/default.nix` line 11 imports `inputs.home-manager.darwinModules.home-manager` — this makes HM a nix-darwin module.
2. The `home-manager.users.${primaryUser}` config (lines 48-60) sets `imports = [ ../home-darwin ]`, deploying all home-darwin modules.
3. `mkDarwinHost.nix` includes `../darwin` in its module list (line 32), which triggers the HM activation chain.

When `sudo darwin-rebuild switch` runs, it evaluates the full system closure INCLUDING the home-manager module. The resulting activation script handles both system-level and user-level (HM) activation. Running `home-manager switch` afterwards is:
- **Redundant**: same generation is activated twice
- **Potentially conflicting**: if the second `home-manager switch` somehow targets a different flake or evaluation

### Impact

- Extra time per switch (wasted HM activation)
- Possible confusion if standalone `home-manager` and the nix-darwin-integrated HM disagree on something
- The `upgrade` command runs HM switch TWICE after already updating the flake

---

## 4. Duplication and Consolidation Opportunities

### 4.1 REPO_ROOT Detection — 6 different patterns

| Pattern | Scripts | Issue |
|---------|---------|-------|
| `${NIXOS_REPO:-}` or `git rev-parse --show-toplevel` or `$HOME/.nixos` | nixos-build | Triple fallback (good) |
| `git worktree list --porcelain \| grep worktree \| head -1 \| sed` | code-work | Worktree-aware (correct for its purpose) |
| `cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd` | sops-rotate-keys | Resolves symlinks (via `cd` + `pwd`) |
| `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"/..` | add-wireguard-peer, remove-wireguard-peer, generate-thinkpad-wireguard, export-mate-config | Resolves symlinks (subshell) |
| `cd "$(dirname "$0")/.."` | sops-add-t14 | Does NOT resolve symlinks (relative path) |

**Severity**: Low for functionality (scripts work), but high for maintenance. If repo moves or scripts are symlinked differently, some break.

### 4.2 WireGuard Script Family — Shared Preamble

All three (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`) share identical lines 1-8:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
HOST=$(hostname)
cd "$REPO_ROOT"
```

**Recommendation**: Extract into `bin/lib/common.sh` and source it. Reduces 24 duplicate lines to 1 `source` line per script.

### 4.3 Help/Usage Pattern — Inconsistent

- `nixos-build`: manual `echo` statements (lines 104-121)
- `format-nix`: heredoc `cat <<'EOF'` (lines 14-31)
- `code-work`: function `usage()` with `cat >&2 <<EOF` (lines 17-37)
- `sops-rotate-keys`: function `show_help()` (lines 16-29)
- `sync-opencode-remote`: function `usage()` with `cat <<EOF` (lines 47-73)
- `compare-palette`: no help (just runs)
- `webcam`: no help
- WireGuard scripts: inline `echo` with `exit 2`

**Recommendation**: Not urgent, but a shared `usage` helper could reduce boilerplate.

### 4.4 `sops-add-t14` — Candidate for Merging

This is an 8-line script that:
1. `git pull`
2. Runs `sops updatekeys`
3. Stages and commits

It's essentially a convenience wrapper. Could be merged as a subcommand into `sops-rotate-keys` (e.g., `sops-rotate-keys add-host <name>`).

### 4.5 `nixos-build` — Platform-specific code branches

The script has extensive `if $IS_DARWIN` / `else` branching (switch: 13 lines, boot: 9, test: 9, upgrade: 19, dry: 13, build: 8, safe: 27). Many branches duplicate the "print header + do thing" pattern.

---

## 5. How Scripts Are Installed (Full Chain)

```
flake.nix
  -> lib/packages.nix
       linuxPackages.nixos-scripts = callPackage ../pkgs/nixos-scripts { }
       darwinPackages.nixos-scripts = callPackage ../pkgs/nixos-scripts { }
  -> overlays/linux.nix: inherit nixos-scripts (makes it available as pkgs.nixos-scripts)
  -> overlays/darwin.nix: inherit nixos-scripts (same for darwin)
  -> home-linux/shell.nix: home.packages = [ pkgs.nixos-scripts ]
  -> home-darwin/shell.nix: home.packages = [ pkgs.nixos-scripts ]
```

`pkgs/nixos-scripts/default.nix` copies from `../../bin` (the repo's `bin/` directory) and installs only 4 scripts into `$out/bin/`.

For the 8 unpackaged scripts, `home-linux/shell.nix` line 61 adds `~/.nixos/bin` to PATH:
```
PATH = "$HOME/.nixos/bin:$PATH";
```
This makes all 12 scripts available, but only on hosts where the repo is cloned at `~/.nixos` (rog, thinkcentre, t14). mact2 would NOT have the unpackaged scripts available via PATH unless the repo is also cloned there.

---

## 6. Summary of Issues Found

| # | Issue | Severity | Affected |
|---|-------|----------|----------|
| 1 | Double HM activation on mact2 (switch/upgrade/safe) | HIGH | mact2 |
| 2 | 8 scripts not packaged in nixos-scripts | MEDIUM | All hosts |
| 3 | 6 different REPO_ROOT detection patterns | LOW | Maintenance |
| 4 | WireGuard scripts share identical preamble | LOW | bin/ (3 scripts) |
| 5 | sops-add-t14 is trivial, could merge into sops-rotate-keys | LOW | bin/ (2 scripts) |
| 6 | Inconsistent help/usage patterns | LOW | All scripts |
| 7 | Platform branches in nixos-build are verbose | LOW | nixos-build |

---

## 7. Recommended Next Steps

1. **Fix the mact2 double HM bug first** (highest priority): Remove the 3 redundant `home-manager switch` calls from `nixos-build` (lines 131-132, 182-183, 301-302 in the `switch`, `upgrade`, and `safe` commands for Darwin).

2. **Decide on unpackaged scripts**: Either add them to `pkgs/nixos-scripts/default.nix` OR document that they're local-only dev tools. The WireGuard and sops scripts seem important enough to package. `compare-palette` and `webcam` are niche dev tools.

3. **Extract shared library**: Create `bin/lib/common.sh` with:
   - REPO_ROOT detection
   - HOST detection
   - Standardized `die()` and `usage()` helpers
   - Source it from all scripts

4. **Consolidate WireGuard scripts**: Extract the preamble into a sourced common and consider merging `add-wireguard-peer` + `remove-wireguard-peer` into a single `wireguard-peer` script with `add`/`remove` subcommands (matching `code-work`'s pattern).

5. **Merge sops-add-t14**: Fold into `sops-rotate-keys` as an `add-host <name>` subcommand.
