# Exploration: Shutdown Hang Post-Mortem Logging Re-Explore

## Current State

- The first iteration succeeded as instrumentation, not as a fix.
- Latest real hang capture at `/var/log/shutdown-debug/1f15f594-326c-4113-a260-248530a07153/` proves the new shutdown-debug pipeline works: `journal.log`, `dmesg.log`, `ps.log`, `lsmod.log`, `mount.log`, and `nvidia-smi.log` all contain real data.
- The shutdown reaches the late handoff boundary: `systemd-shutdown` runs, extra filesystems unmount, and `zram0` is released. The last journal lines are unmounts plus `zram0: detected capacity change from 32742400 to 0`.
- `nvidia-smi` shows GTX 1050 idle with 0 MiB used and no running GPU processes at shutdown time.
- The failure point is now after userspace teardown, at or immediately before firmware ACPI S5 poweroff.

## What Changed vs First Exploration

- First exploration assumed the missing piece was better shutdown ordering plus better evidence around `rog-shutdown.nix`.
- New evidence rules that out as the primary fix path: userspace already shuts down cleanly even when the machine still hangs.
- The problem has narrowed from "late shutdown ordering" to "firmware / ACPI / EC transition after systemd-shutdown".

## What the Captures Prove

### Proven

- systemd service teardown is not the blocking point
- Docker and network shutdown are not the blocking point
- filesystems and swap teardown are not the blocking point
- the diagnostic service itself is not the blocking point
- NVIDIA userspace activity is not the blocking point

### Strong Signals

- `dmesg` contains ASUS firmware/WMI faults:
  - `ACPI Error: Divide by zero ... \_SB.ATKD.WMNB`
  - `asus_wmi: failed to register LPS0 sleep handler in asus-wmi`
  - `asus_wmi: fan_curve_get_factory_default ... failed: -61`
- `lsmod` shows the ASUS stack is active at shutdown time: `asus_wmi`, `asus_nb_wmi`, `asus_armoury`, and `acpi_call` are loaded.
- The host is an older ATK/ATKD-style ASUS firmware (`asus-nb-wmi: Detected ATK, not ASUSWMI, use DSTS`), which fits the WMNB failure pattern.

### Ruled Out or Deprioritized

- Generic systemd ordering changes as the main fix
- More shutdown logging as the main next change
- NVIDIA mismatch as root cause (already fixed separately; capture still hangs)
- `_SI._SST` alone as a sufficient workaround

## Most Likely Root Causes

1. **Broken ASUS firmware AML at S5 transition**
   - The `\_SB.ATKD.WMNB` divide-by-zero error points at buggy ASUS WMI/ATKD AML, not normal userspace shutdown.
   - This is the best match for "Linux shutdown completes, then firmware never powers off".

2. **ASUS EC / WMI state corruption or incompatibility before poweroff**
   - `asus-fan-control` writes directly through `acpi_call` to EC methods (`\_SB.PCI0.LPCB.EC0.WRAM` / `RRAM`).
   - `asus_wmi` fan-curve queries already fail on this machine, so fan/EC-related firmware paths look fragile.
   - This is not proven as the cause, but it is now the top software-level suspect.

3. **Late kernel-driver / device poweroff quirk on ASUS hardware**
   - Since the hang happens after `systemd-shutdown`, a remaining kernel module or device poweroff sequence may still need a very-late unload or quirk.
   - Old ASUS reports commonly use last-second module unloads or DSDT `_PTS`/S5 workarounds.

## Affected Areas

| Area | Impact | Why |
|------|--------|-----|
| `modules/hardware/rog-shutdown.nix` | High | Current `_SI._SST` service is too early and too narrow for a firmware-boundary issue |
| `modules/hardware/asus-fan-control.nix` | High | Needs isolation or controlled disable/test because it mutates ASUS EC state |
| `hosts/rog/default.nix` | High | Host-specific toggles, module imports, kernel params, and experiment switches live here |
| `modules/base/shutdown-debug.nix` | Medium | May need minor additions for late-hook breadcrumbs, but not major redesign |
| `modules/hardware/nvidia.nix` | Low | No current evidence it is causal; only relevant if testing late module unload variants |

## Approaches

| Approach | What to try next | Pros | Cons | Complexity |
|----------|------------------|------|------|------------|
| A | Replace the current fix path with a **very-late `/usr/lib/systemd/system-shutdown/` hook** that runs after `systemd-shutdown`, optionally unloads suspect modules, and only then attempts ACPI fallback calls | Matches the real failure boundary; best place for last-second poweroff workaround experiments | Harder to log to `/var`; limited environment; may require several iterations | Medium |
| B | **Isolate ASUS WMI / fan-control state**: disable `asus-fan-control`, optionally unload `asus_wmi` / `asus_nb_wmi` / `asus_armoury` before poweroff, compare behavior | Directly tests the strongest remaining software suspect; relatively small Nix change | Could reduce fan/hotkey behavior; may not fix if firmware bug is deeper | Low-Medium |
| C | Build a **firmware-level workaround path**: acpidump, inspect `_PTS` / related AML, and if needed ship a model-specific DSDT/SSDT override | Best long-term answer if firmware AML is truly broken | Highest risk and effort; easiest to get wrong; should be last resort | High |

## Recommendation

Recommend **Approach B plus A in the same next iteration, in that order**:

1. First, stop treating `rog-shutdown.nix` as the primary fix.
2. Add a host-scoped experiment to disable `asus-fan-control` and/or unload ASUS WMI modules before poweroff.
3. Move the actual poweroff workaround experiment to a `/usr/lib/systemd/system-shutdown/` hook, because systemd documents that these hooks run shortly before the final poweroff, after most services, mounts, and swap are already gone.

Why this is the best next iteration:

- It aligns with the real hang location.
- It tests the most plausible software lever left: ASUS EC/WMI state.
- It is much cheaper and safer than jumping straight to DSDT override work.

## File Changes for the Next Iteration

- `modules/hardware/rog-shutdown.nix`
  - Replace the current standalone `_SI._SST` service model or reduce it to a wrapper for a later hook.
- `modules/hardware/asus-fan-control.nix`
  - Add an easy host-level off switch and possibly a shutdown-time unload/reset experiment path.
- `hosts/rog/default.nix`
  - Wire host-specific experiment toggles for ASUS fan/WMI shutdown tests.
- `modules/base/shutdown-debug.nix`
  - Optional: add tiny late-hook breadcrumbs written to `/run` or journal earlier, not another big logging redesign.
- Possibly a new module, e.g. `modules/hardware/rog-poweroff-workaround.nix`
  - Preferred place for a dedicated late poweroff hook instead of overloading `rog-shutdown.nix`.

## Should `rog-shutdown.nix` Be Replaced Entirely?

**Yes, as the primary remediation path.**

The current `shutdown.target`-era `_SI._SST` approach was useful as an experiment, but the captures show the real hang is later than that. If the file remains, it should be repurposed into a host-specific experiment harness or replaced by a more accurate late-shutdown workaround module. It should no longer be the center of the design.

## Risks

- Disabling ASUS fan control may worsen thermals or remove preferred fan behavior until validated.
- Unloading `asus_wmi`/related modules late may break hotkey/backlight cleanup paths or still fail to change S5 behavior.
- If both A and B fail, the next step is likely firmware override territory, which is riskier and more invasive.
- `nixos-hardware` has ASUS profiles, but no existing GL553VD shutdown quirk to reuse directly; nearby ASUS profiles are not sufficient evidence of a ready-made fix.
