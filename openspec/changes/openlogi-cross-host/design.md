# Design: OpenLogi on t14 and macm5

## Technical Approach

Implement proposal revision 3 and `specs/openlogi-platform-integration/spec.md` using upstream platform ownership. Exploration #3686 supplies feasibility evidence, not runtime acceptance. Only t14 imports the reusable Linux module; macm5 adds its existing managed cask. No deployment, commit or push is authorized.

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| Local Linux import versus builder wiring | Upstream integration without per-consumer plumbing | `linux/system/hardware/openlogi.nix` owns upstream import and enablement; existing `specialArgs.inputs` suffices. Builders remain unchanged. |
| Root nixpkgs follows versus newer t14 input | Stable graphics dependencies versus unnecessary boundary expansion | Pin `openlogi` to v0.8.11 commit `7a9d092a7dda0cb3b7ec18ada4424d681fca65ca`, following root `nixpkgs`; retain upstream locked rust-overlay/toolchain. |
| Managed cask versus custom DMG/LaunchAgent | Rolling versions versus additional packaging/lifecycle ownership | Add `openlogi` to existing Homebrew casks; preserve autoUpdate/upgrade/cleanup and embedded Login Item. No cross-platform version parity promise. |
| GUI files versus HM TOML | Mutable configuration versus activation overwrite risk | Keep local GUI-owned files and backups; no seed, mappings or synchronization. |

Use a narrow input-lock operation, not unrestricted flake update. Compare parsed lock graphs with the pre-change snapshot: every existing unrelated node/pin and root edge must remain unchanged. Only OpenLogi and necessary new dependency nodes/edges may differ.

`mkHost.nix` rebinds host `inputs.nixpkgs`, but does not reconstruct another input's output closure. The upstream module selects `self.packages.${pkgs.stdenv.hostPlatform.system}.openlogi`; its dependencies follow the root lock, not host argument rebinding. Current t14 NixOS uses root nixpkgs; Quattro's newer packages are narrowly overlaid. Do not route OpenLogi through t14-nixpkgs or override its package without demonstrated need.

## Data Flow

t14 import → local module → pinned upstream package/udev/user service → local agent ↔ GUI/config ↔ devices.

macm5 Homebrew → signed arm64 app → embedded agent/Login Item ↔ local GUI/config/devices. No inter-host channel or firewall change.

## File Changes

| Path | Action | Purpose |
|---|---|---|
| `flake.nix` | Modify | Pinned OpenLogi input and root follows |
| `flake.lock` | Modify | Narrow new dependency closure |
| `linux/system/hardware/openlogi.nix` | Create | Upstream import and enablement |
| `hosts/t14/default.nix` | Modify | One explicit hardware-section import |
| `darwin/system/homebrew.nix` | Modify | One native cask entry |

Builders, shared HM lists, rog/thinkcentre and generated hardware files remain untouched.

## Interfaces / Contracts

Release source verifies `inputs.openlogi.nixosModules.default`; `programs.openlogi.enable` is boolean, `package` a derivation, and `launchAtLogin` boolean/default true. Set enable true; retain package/login defaults. Upstream registers package/udev rules and `systemd.user.services.openlogi-agent`: graphical-session WantedBy/After/PartOf, package-qualified ExecStart, on-failure restart. Nix owns Linux startup; avoid GUI-created competing units. MCP confirms `services.udev.packages` and Darwin `homebrew.casks`; OpenLogi options are external, absent from the nixpkgs index.

## Testing Strategy

Use focused inline evaluation assertions, not new frameworks/check scaffolding.

1. Preserve dirty baseline; format three touched Nix files; run `nix flake check --no-build`.
2. Evaluate t14 and macm5 toplevel drvPaths separately. Assert package/udev membership, exact ExecStart and session dependencies; cask membership and unchanged rolling policy.
3. Evaluate rog/thinkcentre with absent-option-safe checks: no OpenLogi package, service or added permissions. Compare excluded imports, lock nodes and builders against baseline.
4. Build exactly `.#nixosConfigurations.t14.config.programs.openlogi.package`, recording drvPath/result. Native macm5 toplevel build is separate; defer if unavailable. Evaluation proves neither compilation nor cask installation.
5. After separately authorized deployment: verify one agent, seat ACLs, socket isolation, Hyprland foreground backend, Agent privacy grants, local save/reload/backups and competing-manager absence. Probe K780 discovery/battery/supported controls and G305 battery/DPI read-write-restore; identify probable G502 before claims. Missing access fails acceptance without permission widening.

## Threat Matrix

Process integration applies; all reference rows are inapplicable:

| Boundary | Applicability/reason |
|---|---|
| Documentation-like paths | N/A: no executable classification |
| Git repository selection | N/A: no VCS automation |
| Commit state | N/A: no commit behavior |
| Push state | N/A: no push behavior |
| PR commands | N/A: no PR composition |

No matrix RED tests are required; service/access contracts above remain acceptance gates.

## Migration / Rollout

No option migration. Before deployment retain generations, signed macOS artifact and matching config backups. Reverse only these changes; stop the owned agent before restoring another manager. Restore mutable/device state and Login Item/TCC grants separately; Nix rollback cannot restore Homebrew versions.

## Open Questions

Native socket isolation, lifecycle/permissions and device capabilities remain unproven. Probable G502 variant and K780 transport require native identification; none blocks implementation planning.
