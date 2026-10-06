# Proposal: OpenLogi on t14 and macm5

## Intent

Adopt OpenLogi on t14 and macm5. Cross-host means platform coverage, not switching. Handoff revision 3 authorizes planning, implementation and verification; not deployment, commit or push.

## Scope

### In Scope
- t14-only Linux enablement through one reusable explicit import.
- macm5 native Homebrew cask, retaining existing rolling updates rather than exact version parity.
- GUI-owned mutable host-local settings; defaults and GUI configuration, without mandatory bindings.
- Separate configuration, build and postdeployment hardware evidence.

### Out of Scope
- rog/thinkcentre changes; Flow, synchronization, EasySwitch automation, shared HM TOML.
- Broad input permissions, firewall openings, extra Darwin LaunchAgent, unreleased gaming features.

## Capabilities

### New Capabilities
- `openlogi-platform-integration`: selective Linux module, native Darwin ownership, local settings, bounded permissions/lifecycle, staged acceptance and recovery.

### Modified Capabilities
None; preserve existing macm5 onboarding requirements.

## Approach

Follow `exploration.md` / Engram #3686; revision 3 supersedes their authorization gate. Pin AprilNEA/OpenLogi v0.8.11 commit `7a9d092a7dda0cb3b7ec18ada4424d681fca65ca`, using repository nixpkgs and upstream toolchain. The Linux module owns upstream import and enablement; future hosts need only its import. Reuse upstream udev/graphical-session lifecycle and Darwin's signed app/embedded Login Item. Keep GUI and agent compatible.

## Affected Areas

| Path | Impact |
|---|---|
| `flake.nix`, `flake.lock` | Pinned Linux input |
| `linux/system/hardware/openlogi.nix` | New reusable module |
| `hosts/t14/default.nix` | Single explicit import |
| `darwin/system/homebrew.nix` | Add `openlogi` cask |

Builders, shared HM lists, excluded hosts and generated hardware files remain unchanged.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Build/toolchain failure | Medium | Exact derivation build; evaluation is not compilation |
| Device/Wayland/permission limitations | Medium | Native probes; no invented support or permission widening |
| Manager contention/schema drift | Medium | One owner; matching backups and retained artifacts |

## Rollback Plan

Revert only this change's input/lock, import/module and cask entry, preserving dirty work. Before deployment retain known-good generations, signed macOS artifact and matching config backups. Stop the agent through its owner before restoring any prior manager. Separately restore mutable config/device state and remove unwanted Login Item/TCC grants; Nix rollback does not restore these or Homebrew versions.

## Dependencies

Upstream release/toolchain, existing Homebrew, later authorized native sessions and actual receivers.

## Success Criteria

- [ ] Format, flake check and t14/macm5 evaluations pass; rog/thinkcentre lack enablement.
- [ ] Exact Linux package builds; record Darwin native build separately, deferred if unavailable.
- [ ] After separately authorized deployment: verify single-agent lifecycle, seat ACLs/socket isolation, Hyprland foreground backend, Agent Accessibility/Input Monitoring and config persistence.
- [ ] Native K780 discovery/battery and supported controls, G305 battery/DPI read-write-restore are evidenced or explicitly limited. Probable G502 LIGHTSPEED model/variant remains unknown until native identification; no remapping/profile guarantees.
