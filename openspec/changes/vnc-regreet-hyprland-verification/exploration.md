# Re-Exploration: VNC regreet + Hyprland — output selection fix

## Summary

Investigation into why wayvnc in the greeter Hyprland session captures the wrong monitor (DP-5 portrait instead of DP-3 landscape where regreet appears). Researched CLI flags, config file options, NixOS integration, headless virtual output alternatives, and existing greeter infrastructure. **Recommended approach: add `output` option to `omarchy.greeter.wayvnc` with `-o` CLI flag.**

## Current State

### What works (from prior apply progress)
- `omarchy.greeter.wayvnc` submodule exists (enable, address, port, enable_pam)
- wayvnc exec-once injected correctly before greeter-regreet-start (line 260, system.nix)
- tmpfiles C+ rule fixed and deployed — config file has correct content
- `nix flake check --no-build` passes all hosts
- wayvnc runs on port 5900 with correct config
- `focusMonitor = "LEN G24"` (line 184, hosts/t14/default.nix) — this monitor is NOT connected, so the focus/disable logic is a no-op

### What's broken
- wayvnc captures DP-5 (AOC 24P1W1, portrait, transform:1 at 0x0) — the first/focused output
- Regreet appears on DP-3 (AOC 2470W, landscape at 3000x420)
- User cannot interact with regreet via VNC (wrong monitor)

### Greeter monitor layout (from hyprctl on t14)
```
DP-3: AOC 2470W, 1920x1080@60, 3000x420, scale 1  (landscape)
DP-5: AOC 24P1W1, 1920x1080@60, 0x0, scale 1, transform 1  (portrait, FOCUSED)
eDP-1: disabled (external monitors connected)
```

### Root cause
wayvnc's default behavior captures the first available output. In the greeter Hyprland session, DP-5 is at position (0,0) and is the focused output. The greeter script disables eDP-1 when externals are connected, but leaves both DP-3 and DP-5 active. DP-5 becomes the default capture target. The `focusMonitor` option ("LEN G24") doesn't match any connected monitor, so its disable-others logic never executes.

### Timing constraint
wayvnc selects its output during Wayland initialization, picking `output_first()` when `-o` is not specified. This happens BEFORE the greeter script runs. Even if the greeter script disables DP-5, wayvnc already captured it. A race condition exists between wayvnc startup and the greeter script's monitor manipulation — we cannot rely on the greeter script to fix the output selection after wayvnc starts.

## Research Findings

### 1. wayvnc CLI flags — verified against source and man pages

| Flag | Behavior |
|------|----------|
| `-o <name>` / `--output=<name>` | Captures a specific output by short name (DP-3, eDP-1, HEADLESS-2, etc.) |
| `-a` / `--desktop` | Captures ALL outputs as one giant combined desktop |
| (no flag) | Captures first available output (what we have now — picks DP-5) |

Runtime control via `wayvncctl`:
- `wayvncctl output-list` — list all outputs and which is captured
- `wayvncctl output-set <name>` — switch capture to a different output at runtime
- `wayvncctl output-cycle` — rotate through available outputs
- `wayvncctl event-receive` — wait for CLIENT-CONNECTED/CLIENT-DISCONNECTED events

The `-v` (verbose) flag prints all output names at startup, useful for debugging.

### 2. wayvnc config file — confirmed CLI-only for output

Read the `cfg.c` source (parser) and `X_CFG_LIST` macro, plus all man pages (Arch, Debian, Ubuntu, openSUSE). The config file **does NOT** support `output` or `output_name` as a key.

Supported config keys: `address`, `port`, `enable_auth`, `enable_pam`, `certificate_file`, `private_key_file`, `rsa_private_key_file`, `username`, `password`, `use_relative_paths`, `allow_broken_crypto`, `xkb_layout`, `xkb_model`, `xkb_options`, `xkb_rules`, `xkb_variant`.

Output selection is strictly CLI-only. Config file option is not viable.

### 3. NixOS wayvnc module — minimal

- Only `programs.wayvnc.enable` and `programs.wayvnc.package`
- No home-manager module
- Our implementation does NOT use the NixOS module — we use `exec-once` directly in Hyprland config
- No existing NixOS infrastructure for output selection

### 4. Hyprland headless virtual output — not viable for mirroring

- `hyprctl output create headless` creates HEADLESS-N output at runtime
- Can be declared statically: `monitor=HEADLESS-1,1920x1080@60,0x0,1`
- Defaults to 1920x1080@60 (matching DP-3 resolution)
- Multiple community projects use this pattern (Ghost-Monitor, sunshine-hyprland-virtual-display, single-output-sway)
- **Blocking problem for our use case**: regreet is a single GTK window. It can only appear on ONE output. A headless virtual output would give VNC its own separate screen — the VNC view would show the headless (empty) while regreet appears on DP-3. Hyprland does not support output mirroring. To make headless work, we'd need to move regreet to the headless output, but then the physical display shows nothing. Headless is appropriate for dedicated remote-desktop use cases (Sunshine/game-streaming) but not for login-screen mirroring.

### 5. Existing focusMonitor infrastructure — promising but has timing issue

The greeter script (system.nix lines 196-225) already has logic to:
1. Match a monitor by description substring (`focusMonitor` option)
2. Disable all external monitors except the target
3. Focus on the target monitor

Currently on t14, `focusMonitor = "LEN G24"` — this monitor is NOT connected, so the logic is a no-op. Both DP-3 and DP-5 remain active.

**If we set focusMonitor to match DP-3** (e.g., `focusMonitor = "AOC 2470W"`), the greeter script would:
- Match DP-3 as the target
- Disable DP-5
- Focus on DP-3
- Phase 2 disables eDP-1
- Result: only DP-3 active, regreet on DP-3

**But timing problem**: wayvnc exec-once runs BEFORE the greeter script. wayvnc connects to Wayland and selects its output during initialization. By the time the greeter script runs and disables DP-5, wayvnc has already chosen DP-5. The output selection happens once at startup (not re-evaluated when monitors change).

This makes the focusMonitor approach insufficient on its own — wayvnc needs explicit output targeting.

## Approaches Evaluated

### Approach A: Add `output` option to `omarchy.greeter.wayvnc` (RECOMMENDED)

Add a new `output` string option and pass it as `-o <value>` to wayvnc.

**Implementation**:
- `config.nix`: Add `output` option (string, default `""`)
- `system.nix` (line 260): Modify `wayvncExec` to include `-o ${output}` conditionally
- `hosts/t14/default.nix`: Set `wayvnc.output = "DP-3"`

**Pros**:
- Explicit intention: "capture THIS output"
- Simple: ~6 lines of code change total
- Prevents race: wayvnc selects the right output at startup
- Flexible: different hosts can set different outputs
- Backward compatible: empty default = no `-o` flag = current behavior preserved
- Follows existing submodule pattern

**Cons**:
- Output names (DP-3) are kernel-assigned and could theoretically change
- If the specified output isn't available, wayvnc fails (but is backgrounded with `&`, so regreet still works on physical display)
- Requires maintaining the output name in host config if hardware changes

### Approach B: `-a` flag (capture all outputs)

**Implementation**: Add `-a` to wayvnc exec-once line.

**Pros**:
- Simplest code change: one flag

**Cons (BLOCKING)**:
- Creates a giant combined desktop spanning both monitors: ~3000x1920 virtual screen
- Most of the screen is empty space between the two monitors
- Regreet appears only on a small portion (DP-3 region at 3000x420 offset)
- Terrible user experience for a greeter login screen
- **REJECTED** — not viable for greeter use case

### Approach C: focusMonitor-only (no wayvnc changes)

**Implementation**: Change `focusMonitor = "LEN G24"` to `focusMonitor = "AOC 2470W"` in t14 config.

**Pros**:
- Zero code changes to omarchy-nix
- Only one line change in nixos-hosts
- Uses existing infrastructure

**Cons (BLOCKING)**:
- **Timing race**: wayvnc starts before the greeter script, selects DP-5 as output before DP-5 is disabled
- wayvnc output selection happens once at initialization; it does NOT re-evaluate when outputs are disabled
- By the time the greeter script disables DP-5, wayvnc is already capturing a disabled/missing output (black screen)
- **REJECTED** — timing issue makes this unreliable

### Approach D: Headless virtual output

**Implementation**: Create HEADLESS-1 in Hyprland config, run wayvnc with `-o HEADLESS-1`, reroute regreet to headless.

**Pros**:
- Clean separation: VNC gets its own dedicated output
- No dependency on physical output names
- Consistent resolution

**Cons (BLOCKING)**:
- regreet is a single GTK window — can only appear on ONE output
- Hyprland does NOT support output mirroring
- To show regreet on both physical (DP-3) and virtual (HEADLESS-1), we'd need two regreet instances or output mirroring — neither is supported
- Fundamentally changes the architecture from "mirror the login screen" to "separate virtual login screen"
- **REJECTED** — doesn't solve the mirroring problem

### Approach E: Combine focusMonitor + wayvnc output sync

**Implementation**: Set `focusMonitor = "AOC 2470W"` AND add `-o DP-3` to wayvnc.

**Pros**:
- focusMonitor disables DP-5 for the greeter session (cleaner physical display)
- wayvnc `-o DP-3` guarantees capture of the right output regardless of timing
- Both work independently — each provides value without the other

**Cons**:
- Two changes instead of one
- focusMonitor name matching is separate from wayvnc output name (description vs short name)

**Verdict**: This is actually the best outcome. focusMonitor ensures only the landscape monitor is active during the greeter session. wayvnc `-o DP-3` captures the correct output. They complement each other.

### Approach F: `omarchy.greeter.monitors` to statically configure only DP-3

**Implementation**: Set `omarchy.greeter.monitors` to include only the AOC 2470W description, which makes Hyprland only create that output.

**Pros**:
- Zero code changes to any repo
- Only a config change in t14

**Cons**:
- Requires full monitor description string (verbose, hardware-specific)
- If AOC 2470W is unplugged, greeter has no monitors and falls back to eDP-1
- Doesn't address wayvnc output selection (still relies on "first available" = correct)
- Less explicit about intent

**Verdict**: Works but less maintainable than explicit `output` option.

## Recommendation: Hybrid Approach (A + E)

**Recommended**: Add `output` option to `omarchy.greeter.wayvnc` AND update `focusMonitor` on t14.

### Why this combination

1. **`output` option (Approach A)** — tells wayvnc exactly which output to capture via `-o DP-3`. Definite, no race, no ambiguity.

2. **`focusMonitor` update (Approach E complement)** — change from `"LEN G24"` to `"AOC 2470W"`. This makes the greeter script disable DP-5, creating a cleaner single-monitor greeter session on DP-3. The physical display shows only regreet on DP-3 (no wasted desktop space on the portrait monitor).

Each change works independently — if the `-o` flag does its job, focusMonitor is a nice-to-have for a cleaner physical greeter experience. If focusMonitor is set but wayvnc doesn't have `-o`, the timing issue means wayvnc still captures the wrong output.

### Tradeoffs

| Aspect | Assessment |
|--------|------------|
| Complexity | Low — ~6 lines of code in omarchy-nix, ~2 lines in nixos-hosts |
| Fragility | Low — DP-3 is stable for this hardware/dock setup. If names change, update one option |
| UX | Excellent — VNC shows the same regreet the physical user sees on DP-3 |
| Nix integration | Clean — follows existing submodule pattern, single boolean gate |
| Backward compatibility | Full — empty default preserves current behavior for all other hosts |

### Risk: output name instability

Output names like DP-3 are assigned by the kernel/drm subsystem based on connector enumeration order. They can change if:
- Monitors are plugged into different ports
- A docking station is replaced
- Kernel/driver updates change enumeration order

Mitigations:
- The option is explicit and documented — if names change, the host admin updates one line
- If the specified output doesn't exist, wayvnc fails silently (backgrounded), so regreet works without VNC
- For t14's fixed hardware (always same dock, same two monitors), DP-3 is stable
- Future enhancement: could support description-based matching in the greeter script, resolving to output name before passing to wayvnc (but this requires wayvnc to start AFTER the greeter script, which breaks the current "wayvnc before regreet" ordering)

## Implementation Sketch

### omarchy-nix changes

**1. `config.nix`** — Add `output` option inside the `wayvnc` submodule (after `enable_pam` at line 390):

```nix
output = lib.mkOption {
  type = lib.types.str;
  default = "";
  description = "Output name for wayvnc to capture (e.g. DP-3, eDP-1). Leave empty to capture the first available output.";
  example = "DP-3";
};
```

**2. `modules/nixos/system.nix`** — Modify `wayvncExec` let-binding (line 260):

```nix
# Before:
wayvncExec = lib.optionalString cfg.greeter.wayvnc.enable "exec-once = ${pkgs.wayvnc}/bin/wayvnc ${cfg.greeter.wayvnc.address} ${toString cfg.greeter.wayvnc.port} &\n";

# After:
wayvncExec = lib.optionalString cfg.greeter.wayvnc.enable (
  "exec-once = ${pkgs.wayvnc}/bin/wayvnc"
  + lib.optionalString (cfg.greeter.wayvnc.output != "") " -o ${cfg.greeter.wayvnc.output}"
  + " ${cfg.greeter.wayvnc.address} ${toString cfg.greeter.wayvnc.port} &\n"
);
```

### nixos-hosts changes

**3. `hosts/t14/default.nix`** — Update greeter block (lines 204-208):

```nix
# Before:
wayvnc = {
  enable = true;
};

# After:
wayvnc = {
  enable = true;
  output = "DP-3";
};
```

**4. `hosts/t14/default.nix`** — Update focusMonitor (line 184):

```nix
# Before:
focusMonitor = "LEN G24";

# After:
focusMonitor = "AOC 2470W";
```

### Estimated lines of change

| File | Lines | Type |
|------|-------|------|
| `omarchy-nix/config.nix` | +5 | New option |
| `omarchy-nix/modules/nixos/system.nix` | +3 −1 | Modified wayvncExec |
| `hosts/t14/default.nix` | +1 | New wayvnc.output value |
| `hosts/t14/default.nix` | −1 +1 | Changed focusMonitor |
| **Total** | **~8 changed lines** | |

### What does NOT change

- No changes to tmpfiles rules (config file is untouched)
- No changes to the greeter script (monitorBlock, cursorEnv, inputBlock)
- No changes to regreet or Hyprland configuration
- No new dependencies
- No structural changes to the option tree

### Generated exec-once line (example)

```
exec-once = /nix/store/...-wayvnc-.../bin/wayvnc -o DP-3 0.0.0.0 5900 &
```

## Updated Scope

Given the C+ tmpfiles bug is already fixed (commit 7e34e85 in omarchy-nix, commit af5c957 in nixos-hosts), the remaining verification scope is:

### Completed
- [x] Config inspection (tasks 2.1, 2.2) — PASS after C+ fix
- [x] Build verification — flake check passes

### Blocked (requires output fix)
- [ ] E2E VNC test (task 3.2) — blocked by wrong monitor capture
- [ ] Custom port test (task 3.3) — depends on task 3.2
- [ ] Negative test (task 3.4) — depends on task 3.2

### New work (output fix)
- [ ] Add `output` option to `omarchy.greeter.wayvnc` in config.nix
- [ ] Modify `wayvncExec` in system.nix to pass `-o` conditionally
- [ ] Set `wayvnc.output = "DP-3"` and update `focusMonitor` in t14 config
- [ ] Verify `nix flake check --no-build` passes all hosts
- [ ] Deploy on t14 and verify wayvnc captures DP-3
- [ ] Resume Phase 3 E2E verification from task 3.2

## Affected Areas

| Area | Change |
|------|--------|
| `omarchy-nix/config.nix` | New `output` option in wayvnc submodule (+5 lines) |
| `omarchy-nix/modules/nixos/system.nix` | Modified `wayvncExec` (+3-1 lines) |
| `hosts/t14/default.nix` | Set `output = "DP-3"`, update `focusMonitor` (+1, -1+1 lines) |
| Verification tasks 3.2-3.4 | Unblocked once output fix is deployed |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| DP-3 name changes after kernel/driver update | Low (fixed hardware) | If name changes, wayvnc fails silently; update option value |
| `focusMonitor = "AOC 2470W"` doesn't match DP-3 exactly | Low | Verify description substring via `hyprctl monitors` on t14 before deploying |
| Output option is empty on t14 (forgot to set) | Low (just set it) | Default is current behavior — VNC works but shows wrong monitor; detect via verification |
| wayvnc fails because DP-3 isn't available | Low (it's always connected) | Backgrounded with `&` — regreet works on eDP-1 fallback; only VNC is affected |
| Build breaks on non-t14 hosts | None | New option has a default; only t14 opts into non-default value |

## Next Steps

1. **Implement**: Add `output` option in omarchy-nix, update wayvncExec
2. **Configure**: Set `output = "DP-3"` and `focusMonitor = "AOC 2470W"` in t14
3. **Build**: `nix flake check --no-build` on all hosts
4. **Deploy**: `nixos-build switch` on t14
5. **Verify**: Resume Phase 3 E2E VNC verification (task 3.2)
