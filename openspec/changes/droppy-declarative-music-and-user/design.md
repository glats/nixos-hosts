# Design: Declarative Droppy Music, Preserved Native Accounts

## Technical Approach

Implement the proposal and `specs/droppy-music-access/spec.md` on `rog` only. Retain the pending read-only music volume; remove rejected account provisioning only during separately authorized apply. Preserve the persistent configuration, all native accounts, existing service behavior, image, ports, nginx, permissions timer, and unrelated dirty work. This document authorizes no implementation or deployment.

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| Existing OCI `volumes` music bind | Minimal; Docker `-v` creates missing source directories | Keep `/run/media/library/music:/files/music:ro`, as specified; gate authorized deployment before any service action. |
| New startup guard or different bind syntax | Stronger failure semantics; additional functional change | Not selected: the spec defines acceptance failure, not autonomous startup failure, and permits only the music mount as a retained functional change. Stronger guarantees require an explicit spec amendment. |
| Native persistent accounts | Not reproducible from Nix | Preserve `/srv/glats/droppy/config:/config`; no DB reads/writes, seeding, credential artifacts, or account recreation. |
| SOPS seed/preStart | Adds rejected credential authority and DB writes | Remove only this change's pending mechanism and artifacts during approved apply. |

## Mount Topology and Failure Contract

`hosts/rog/default.nix:173-177` declares ext4 `/run/media/library`, UUID `608cd7cf-3cb4-4589-8f36-c558fb4e32a3`, with `defaults`; it is neither an automount nor `nofail`. Read-only design inspection confirmed that UUID mounted at `/run/media/library` (`/dev/sdc1`) and the music directory exists. These observations are not deployment acceptance.

Evaluated `docker-droppy` orders after Docker/socket/network-online, with no explicit library requirement. Installed unit inspection shows normal `sysinit.target` ordering; the library mount precedes `local-fs.target`. Normal boot ordering therefore helps, but does not guarantee the music subdirectory exists or prevent later mount loss.

Pinned nixpkgs `nixos/modules/virtualisation/oci-containers.nix:485` translates each volume to `-v`; evaluation confirms the exact music argument. Docker Context7 `/docker/docs` confirms missing `-v` sources are created, unlike `--mount`. Do not claim startup is fail-closed.

The minimum spec-compliant gate is read-only preflight immediately before any separately approved deployment/service start: confirm the exact library mount and UUID and that music resolves within it as a directory. Missing prerequisites block acceptance **and service action**, without `mkdir` or fallback creation. Do not deliberately test absence against the live daemon. Mount disappearance after preflight remains a documented race; autonomous prevention requires amendment, not silent scope growth.

## Data Flow

```text
ext4 library/music -> read-only /files/music -> Droppy -> existing nginx proxy
stuff/droppy      -> existing /files
persistent config -> existing /config -> native accounts/sessions/links
```

## File Changes

| File | Authorized apply action |
|---|---|
| `linux/system/services/web/droppy.nix` | Keep music line; remove inline secret/preStart; preserve the pre-existing `{ config, pkgs, ... }` signature unchanged. |
| `secrets/host/rog/droppy-users.json` | Delete accidental untracked encrypted seed without reading/decrypting it. |
| `linux/system/services/web/droppy.test.py` | Delete rejected-mechanism test; no replacement adjacent test. |

Host imports, filesystem declarations, nginx, and generated hardware files remain unchanged.

## Interfaces / Contracts

Reuse `virtualisation.oci-containers.containers.droppy.volumes`; retain `/config` and `/files` mappings. No new Nix APIs, module options, helper packages, or account interfaces. Preserve non-privileged `shrike`, unchanged `glats`, and every other native record.

## Testing Strategy

| Layer | Planned proof |
|---|---|
| Offline, after apply approval | Format only the module; evaluate `rog` toplevel drvPath; assert three volume strings and generated run command; inspect unit ordering and absence of account-seeding/SOPS references, allowing OCI-generated lifecycle hooks. Review path/hunk-scoped cleanup against dirty baseline. |
| Synthetic, if needed | In sandbox or approved tmp only, exercise missing-source preflight rejection without Docker, credentials, or directory creation. |
| Post-deploy, separately approved | Repeat source preflight before service action; inspect mounted music read-only; browse music and existing files; user confirms logins and unchanged privileges without credential disclosure. No DB mutation tests. |

## Threat Matrix

Documentation-like paths, Git repository selection, commit state, push state, and PR commands: each **N/A**, because this change introduces no classification, VCS automation, or command wrapper. OCI process integration is covered by generated-command inspection and the missing-source gate above; no adversarial live startup test.

## Migration / Rollout

No account migration or full-system activation. Separate approvals gate apply and deployment. Authorized rollback removes only music exposure or uses an inspected previous generation; never restore rejected provisioning or overwrite persistent state.

## Open Questions

None blocking task planning. Strict autonomous missing-source startup failure is outside the current spec and requires explicit amendment and Nix API verification before design expansion.
