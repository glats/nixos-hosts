# Proposal: VNC regreet + hyprland — output selection fix

## Intent

Fix the wayvnc output capture so VNC clients see the correct monitor (DP-3, AOC 2470W landscape) instead of the focused monitor (DP-5, AOC 24P1W1 portrait). This unblocks the remaining E2E verification tasks.

## Scope

### In Scope
- Add `output` option (string, default `""`) to `omarchy.greeter.wayvnc` submodule
- Modify `wayvncExec` in system.nix to include `-o ${output}` when output is set
- Set `output = "DP-3"` in hosts/t14/default.nix
- Update `focusMonitor` from `"LEN G24"` to `"AOC 2470W"` in hosts/t14/default.nix

### Out of Scope
- rog, thinkcentre, mact2 — no changes
- user-session wayvnc — already captures correctly
- Firewall changes
- Changing the monitor layout config

## Capabilities

### Modified Capabilities
- `greeter-wayvnc`: Wayvnc exec-once now includes optional `-o <output>` flag based on the new `output` option. VNC clients connect to the correct monitor.

## Approach

**Hybrid approach (A + E from exploration):**

1. **`omarchy.greeter.wayvnc.output` option** — tells wayvnc exactly which output to capture via `-o DP-3`. Definite, no race, no ambiguity. The `-o` flag is the only way to control wayvnc output selection (no config-file equivalent exists).

2. **`focusMonitor` update** — changing from `"LEN G24"` to `"AOC 2470W"` makes the greeter script disable DP-5, creating a cleaner single-monitor greeter session on DP-3. This is a bonus fix that improves the physical greeter experience.

Each change works independently: the `output` option guarantees VNC correctness regardless of focusMonitor; the focusMonitor update improves the physical display regardless of VNC.

**Implementation detail**: `wayvncExec` conditionally appends `-o ${output}` when `cfg.greeter.wayvnc.output != ""`. When empty string (default), no `-o` flag is emitted, preserving current behavior for all other hosts.

## Affected Areas

| Area | Impact | Lines |
|------|--------|-------|
| `omarchy-nix/config.nix` | Add `output` option to wayvnc submodule | +5 |
| `omarchy-nix/modules/nixos/system.nix` | Add `-o ${output}` to wayvncExec | +2/-1 |
| `hosts/t14/default.nix` (wayvnc) | Set `output = "DP-3"` | +1 |
| `hosts/t14/default.nix` (greeter) | Update focusMonitor | +1/-1 |

**Total**: ~10 lines across 2 repos.

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Output name changes (e.g., DP-3 becomes DP-4) | Low | wayvnc fails gracefully — VNC just won't connect. fix is one config change. |
| `output = ""` on non-t14 hosts | None | Empty string = no `-o` flag = current behavior preserved |
| `focusMonitor` change breaks if AOC 2470W not connected | Low | Greeter script handles missing target gracefully (does nothing, all monitors stay) |

## Rollback Plan

Two independent changes, each individually revertible:

1. **omarchy-nix**: Revert the commit adding `output` option. All hosts return to default (no `-o` flag). wayvnc falls back to capturing first available output.
2. **nixos-hosts**: Revert the `output = "DP-3"` line OR set `output = ""`. Revert `focusMonitor` to `"LEN G24"`.

Rollback time: one commit revert + rebuild per repo (~5 minutes total).

## Dependencies
- omarchy-nix push access
- nixos-hosts push access

## Success Criteria
- [ ] VNC client connects to t14:5900 and sees DP-3 (landscape) output with regreet
- [ ] `nix flake check --no-build` passes all hosts
- [ ] Remaining verification tasks (3.2-4.3) can proceed
