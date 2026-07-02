## Exploration: NixOS Host Pattern Refactor

### Current State

Repo already uses correct community pattern: per-host `default.nix` imports only modules it needs. No monolithic "all hosts" module with `if` branches.

**Composition chain:**
- `flake.nix` → `lib/mkHost.nix` → `hosts/{hostname}/default.nix`
- `mkHost.nix` minimal: adds host dir + sops + home-manager + overlays. No per-host logic.
- rog/thinkcentre use `profiles/server.nix` → `desktop.nix` → `base.nix` (layered aggregation)
- t14 bypasses profiles entirely (imports base modules individually) because omarchy supersedes desktop.nix

**Host conditionals found (exhaustive audit):**

| File | Line | Pattern | Severity |
|------|------|---------|----------|
| `home-linux/btop.nix` | 58 | `hostName != "t14"` | **Anti-pattern** — shared HM module branches on host |
| `home-linux/btop.nix` | 147 | `hostName == "t14"` | **Anti-pattern** — same file, opposite branch |
| `modules/base/home-manager.nix` | 24 | `import ../../hosts/${config.networking.hostName}/home/modules.nix` | Acceptable — dynamic path, not an `if`. Couples HM to host dir layout but works. |
| `hosts/t14/default.nix` | 153 | `hostName = config.networking.hostName` | Benign — passes hostname to HM extraSpecialArgs |

**Only `home-linux/btop.nix` is a real problem.** It's in `shared-modules.nix` (loaded by ALL linux hosts) but contains host-specific branches.

### Affected Areas

- `home-linux/btop.nix` — contains `hostName == "t14"` and `hostName != "t14"` conditionals. Must split into atomic modules.
- `home-linux/shared-modules.nix` — includes `btop.nix` unconditionally. After split, must include only the non-conditional parts (or remove btop entirely and let each host import its variant).
- `hosts/t14/home/omarchy.nix` — already imports selective shared modules. Would need to import t14-specific btop config.
- `hosts/rog/home/modules.nix` — appends host-specific modules to shared list. Would need to import server/desktop btop config.
- `hosts/thinkcentre/home/modules.nix` — same as rog.

### Approaches

1. **Split btop.nix into shared + per-host variants**
   - `home-linux/btop-theme.nix` (theme file only — shared, no conditionals)
   - `home-linux/btop-config.nix` (config for rog/thinkcentre — file-based approach)
   - `hosts/t14/home/btop.nix` (t14 uses `programs.btop.settings` via omarchy)
   - Pros: Clean separation, each host imports what it needs, no conditionals
   - Cons: Two btop config files to maintain (but they're already different)
   - Effort: **Low** — ~30 min

2. **Use `lib.mkIf` with module options (NixOS module system way)**
   - Create `options.btop.variant = mkOption { type = enum [ "file" "settings" ]; }`
   - Each host sets `btop.variant = "file"` or `"settings"`
   - Single module branches on `cfg.variant`
   - Pros: One file, type-safe
   - Cons: Still has conditional inside module (just hidden behind option). Doesn't solve the stated goal.
   - Effort: **Medium**

3. **Remove btop from shared-modules.nix entirely**
   - Each host's `modules.nix` / `omarchy.nix` imports its own btop config
   - Pros: Maximum explicitness, zero conditionals
   - Cons: Slightly more imports per host
   - Effort: **Low**

### Recommendation

**Approach 1 + 3 combined**: Split btop.nix into theme-only (shared) + config (per-host). Remove `btop.nix` from `shared-modules.nix`. Each host imports its variant explicitly:
- rog/thinkcentre: import `home-linux/btop-file.nix` in their `modules.nix`
- t14: import `home-linux/btop-settings.nix` in `omarchy.nix` (or let omarchy handle it)
- Theme file stays in shared list (no conditionals, just writes `~/.config/btop/themes/nix-colors.theme`)

This matches the repo's existing pattern: per-host import lists, no branching.

### Risks

- **Low risk**: Only one file (`btop.nix`) needs refactoring. Rest of repo is already clean.
- **Test risk**: Must verify btop renders correctly on all 3 hosts after split. Easy to validate — just check `~/.config/btop/`.
- **Scope creep**: Don't refactor `home-manager.nix` dynamic import — it works fine and isn't an `if` conditional.

### Ready for Proposal

**Yes.** Scope is small: one file to split, three import lists to update. The repo is already well-structured; this is a targeted fix for the one remaining anti-pattern.

Orchestrator should tell user: "Repo is 95% clean. Only `home-linux/btop.nix` has hostname conditionals. Fix: split into theme (shared) + config (per-host), remove from shared list, each host imports its variant. ~30 min work."
