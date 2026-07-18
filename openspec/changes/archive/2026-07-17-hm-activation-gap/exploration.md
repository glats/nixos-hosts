## Exploration: HM Activation Gap — Deleted mutable configs not recreated by nixos-rebuild switch

### Problem Statement

When a user deletes `~/.config/opencode` (or any HM-managed mutable directory) and runs `nixos-build switch` (i.e., `nixos-rebuild switch` / `nh os switch`) **without any Nix configuration changes**, the deleted directory and its files are NOT recreated. The user must explicitly run `home-manager switch --flake .#host` (`hms`) to restore them. This creates a silent UX gap where `nixos-rebuild switch` appears to succeed but leaves the system in a broken state.

### Current State

Home Manager configs are integrated into NixOS in two modes:

**Mode 1 — NixOS-integrated (default for `nixos-rebuild switch`)**:
`lib/mkHost.nix` (line 24) adds `inputs.home-manager.nixosModules.home-manager` to every NixOS host (rog, thinkcentre, t14). This creates a systemd service `home-manager-glats.service` whose `ExecStart` points to a specific HM activation script store path. Systemd only restarts this service when the store path changes — i.e., when the HM closure is rebuilt to a different output.

**Mode 2 — Standalone (`home-manager switch`)**:
`flake.nix` (lines 249–324) defines standalone `homeConfigurations` for all hosts. Running `home-manager switch --flake .#host` bypasses systemd entirely and always runs full HM activation.

The `shared/opencode.nix` module (used by ALL hosts, Linux and Darwin) deploys OpenCode config via `home.file` entries as symlinks, then has three `home.activation` scripts that run after `linkGeneration`:

| Activation script | Line(s) | Purpose |
|---|---|---|
| `makeOpencodeConfigMutable-default` | 122–223 | Convert symlinks to real files, deploy commands/, skills/, AGENTS.md |
| `setupOpencodePluginRuntime-default` | 226–276 | Copy plugin files, npm packages, DB workaround |
| `syncOpencodeSkillsToOpenfang-default` | 282–313 | Sync skills to OpenFang dir |

All three scripts share the same early-exit pattern (lines 127–129, 231–233, 288–290):

```bash
runtime_dir="${runtimeDir}"   # ~/.config/opencode
if [ ! -d "$runtime_dir" ]; then
  exit 0
fi
```

The `shared/claude-code.nix` module uses the same pattern (activation converts symlinks to mutable files) but does NOT have an early-exit — it uses `mkdir -p "$claude_dir"` (line 172) to create the directory proactively.

### Root Cause Analysis

**Primary cause: Systemd-based HM activation is change-gated**

When `nixos-rebuild switch` runs with no configuration changes (same nixpkgs rev, same flake inputs, same module code):
1. The NixOS system profile closure is identical → no system level changes
2. The HM generation store path is identical → `home-manager-glats.service` ExecStart path is unchanged
3. Systemd sees no service definition change → does NOT restart the service
4. HM activation never runs → deleted files stay deleted

This is NOT a bug per se — it's the design of NixOS's activation model: only changed services are restarted. But it creates a gap for mutable-state files managed by HM activation scripts.

**Secondary cause: Silently-skipping early-exit in `makeOpencodeConfigMutable`**

The `if [ ! -d "$runtime_dir" ]; then exit 0; fi` guard (shared/opencode.nix, lines 127–129) causes the activation script to silently succeed without creating anything. In the normal case where `linkGeneration` ran first (creating the directory via `home.file` symlink deployment), this guard is not triggered. But it represents a defensive failure: if the directory is absent, the script should repair it, not skip it.

**Contrast with `deployClaudeCodeAssets`** (shared/claude-code.nix, line 172):
```bash
mkdir -p "$claude_dir"   # Creates dir if missing — self-healing
```

This demonstrates the correct pattern already exists in the codebase.

### Evidence Summary

| File | Line(s) | Evidence |
|---|---|---|
| `lib/mkHost.nix` | 24 | `inputs.home-manager.nixosModules.home-manager` — all NixOS hosts use systemd-gated HM |
| `darwin/default.nix` | 15 | `inputs.home-manager.darwinModules.home-manager` — mact2 uses Darwin-equivalent gating |
| `shared/opencode.nix` | 127–129 | `if [ ! -d "$runtime_dir" ]; then exit 0; fi` — silent skip |
| `shared/opencode.nix` | 231–233 | Same pattern in `setupOpencodePluginRuntime` |
| `shared/opencode.nix` | 288–290 | Same pattern in `syncOpencodeSkillsToOpenfang` |
| `shared/claude-code.nix` | 172 | `mkdir -p "$claude_dir"` — correct self-healing pattern |
| `bin/nixos-build` | 125–137 | `switch` command dispatches to `nh os switch` or `nixos-rebuild switch` — no post-switch HM activation |
| `modules/base/home-manager.nix` | 23–25 | NixOS HM config for rog/thinkcentre — per-host `modules.nix` imports |
| `hosts/t14/default.nix` | 248–269 | t14 HM config — imports `./home/omarchy.nix` |
| `darwin/default.nix` | 28–51 | mact2 HM config — imports `home-darwin` |

### Impact Assessment

#### Hosts affected
- **rog** (NixOS desktop) — uses NixOS-integrated HM via `mkHost.nix`
- **thinkcentre** (NixOS headless) — same
- **t14** (NixOS laptop/Omarchy) — same
- **mact2** (macOS/Darwin) — uses `darwinModules.home-manager`, same gating pattern

#### Modules affected beyond opencode
All modules with `home.activation` scripts that modify `home.file` deployments are vulnerable to the same gap. The most impacted are those that **convert symlinks to real files**, because the symlink model is inherently resilient (symlinks reappear when HM activation runs) while real-file deployments require the activation script to run:

| Module | Activation | Risk |
|---|---|---|
| `shared/opencode.nix` | 3 scripts (symlink→real copy, directory management) | **HIGH** — whole `~/.config/opencode/` can vanish |
| `shared/claude-code.nix` | `deployClaudeCodeAssets` | **MODERATE** — uses `mkdir -p`, self-healing; still requires HM to run |
| `shared/gpg.nix` | `importGpgKeys` | Low — only imports keys if missing from keyring |
| `home-linux/git.nix` | `writeGitIdentity` | Low — writes identity files; `mkdir -p` is used |
| `home-darwin/spotlight-index.nix` | `hmAppsSpotlightIndex` | Low — macOS Spotlight re-indexing |
| Regular `home.file` entries | Symlinks created by `linkGeneration` | **MODERATE** — files reappear only when HM runs |

The broadest blast radius is: **any file under `~/.config/` or `~/.local/` managed by HM can be deleted and NOT restored by `nixos-rebuild switch`**.

### Approaches

#### 1. Fix activation scripts to be self-healing (remove early-exit + add mkdir -p)

Replace the early-exit in all three opencode activation scripts with `mkdir -p` (matching the claude-code pattern at shared/claude-code.nix:172).

- **Pros**: Follows existing codebase pattern (claude-code.nix), makes scripts idempotent and self-healing when they DO run, minimal change, no new system-level machinery
- **Cons**: Does NOT address the root cause — if HM activation never runs (no config changes), the directory is still not recreated. Requires companion fix.
- **Effort**: Low (change ~9 lines across shared/opencode.nix)

#### 2. Add post-switch HM activation in `nixos-build`

Modify `bin/nixos-build` to invoke the HM activation script directly after `nixos-rebuild switch` / `nh os switch` / `darwin-rebuild switch`. The HM activation script is idempotent, so running it twice is safe.

```bash
# After switch, ensure HM activation has run:
HM_ACTIVATE="$HOME/.local/state/nix/profiles/home-manager/activate"
if [ -x "$HM_ACTIVATE" ]; then
  "$HM_ACTIVATE" || true
fi
```

- **Pros**: Guarantees HM activation always runs on every `nixos-build switch`, fixes all affected modules at once, simple shell change, works for all hosts
- **Cons**: Adds build time (~few seconds for activation), HM activation path is an implementation detail that could change, might cause double-activation for the NixOS-integrated case (harmless but noisy), does NOT fix `nixos-rebuild switch` run directly (outside `nixos-build`)
- **Effort**: Low (add ~5 lines to bin/nixos-build)

#### 3. Add a NixOS systemd oneshot service with `wantedBy = [ "multi-user.target" ]` that checks and repairs

Create a systemd oneshot service (not tied to HM generation) that runs on every boot and after `nixos-rebuild switch`. It checks for critical directories and triggers HM activation if they're missing.

- **Pros**: System-level guarantee, works for any invocation method (not just `nixos-build`), handles reboot recovery, NixOS-idiomatic
- **Cons**: More complex implementation, needs careful design to avoid conflicts with the existing HM service, might run unnecessarily on every boot, harder to test
- **Effort**: Medium (new NixOS module + service definition)

#### 4. Switch to standalone HM activation in `nixos-build` instead of relying on NixOS integration

Change `nixos-build switch` to call `nixos-rebuild switch` followed by `home-manager switch --flake .#host` (bypassing the NixOS-integrated HM path entirely for mutable-state management).

- **Pros**: Guaranteed full HM activation every time, clean separation of concerns
- **Cons**: Much slower (builds HM separately), redundant with NixOS-integrated path which still runs, potential for conflicting activations, doubles build time
- **Effort**: Low to implement, High operational cost

#### 5. Document the behavior + provide `nixos-build repair` command

Document that `nixos-rebuild switch` only reactivates HM when config changes. Add a `nixos-build repair` command that runs HM activation standalone. Users who deleted configs can run `nixos-build repair` instead of remembering `hms`.

- **Pros**: Simple, no code changes to activation scripts, clear UX
- **Cons**: Does not fix the gap, relies on user awareness, same as current `hms` workaround but with a friendlier name
- **Effort**: Low (add command + docs)

### Recommendation

**Combine Approach 1 + Approach 2**, implemented in two layers:

**Layer 1 — Fix the activation scripts** (remove footgun):
Replace the three `if [ ! -d "$runtime_dir" ]; then exit 0; fi` guards in `shared/opencode.nix` with `mkdir -p "$runtime_dir"` (matching the existing pattern in `shared/claude-code.nix`:172). This makes the scripts self-healing when they DO run and removes a silent-skip that could mask other issues.

**Layer 2 — Add HM activation to `nixos-build switch`** (guarantee activation):
Add a post-switch step in `bin/nixos-build` that directly invokes the HM activation script. This guarantees HM activation runs on every `nixos-build switch`, regardless of whether the NixOS systemd service restarted. The HM activation is idempotent — double execution is safe.

The combination provides defense-in-depth:
- Layer 1 ensures the scripts are robust whenever they run
- Layer 2 ensures they ALWAYS run on `nixos-build switch`
- For direct `nixos-rebuild switch` (outside `nixos-build`), Layer 1 still helps if HM generation happened to change

This approach is minimal, uses existing codebase patterns, and doesn't introduce new system-level complexity.

### Risks

- **HM activation path fragility**: `$HOME/.local/state/nix/profiles/home-manager/activate` is an implementation detail of home-manager. If upstream changes this path, the `nixos-build` post-switch hook breaks silently.
- **Double activation**: On config changes, both the systemd HM service AND the `nixos-build` post-hook run activation. This is harmless (idempotent scripts) but slightly wasteful (~1-2 seconds of redundant work).
- **Darwin path**: The HM activation path on macOS may differ from Linux. The `nixos-build` hook needs to handle both or use `darwin-rebuild`'s equivalent mechanism.
- **Scope creep**: This fix only covers `nixos-build` invocations. Running `sudo nixos-rebuild switch` directly still has the gap. However, `nixos-build` is the documented/recommended entry point in `AGENTS.md`.

### Ready for Proposal

Yes. The exploration confirms a clear root cause with two layers, and a low-effort, low-risk fix combining self-healing activation scripts (following existing claude-code pattern) with a post-switch HM activation hook in `nixos-build`. A proposal can proceed immediately.
