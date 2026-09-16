# Design: LAN SSH Access Mesh

## Technical Approach

Create `shared/ssh/lan-mesh.nix` as the sole reviewed, public-only inventory for `rog`, `thinkcentre`, `t14`, `macm5`, and `oneplus5`. Its helpers derive each Nix target's four peer keys and each source's SSH aliases. Linux consumes it through the existing shared system and Home Manager modules; Darwin aliases are enabled only when the passed host is `macm5`. `oneplus5` consumes the same inventory manually through a runbook, not a Nix deployment.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Registry location | One imported Nix data module under `shared/ssh/` | Per-host literals; SSH CA | Keeps public material auditable and revocable without CA infrastructure. |
| Authorization | Derive keys by target and exclude its own record | Authorize all five; retain ambiguous legacy list | A source never needs to log into itself; exact four-peer lists prevent accidental self-authorization. |
| Darwin scope | Pass `host` into Darwin Home Manager and gate aliases to `macm5` | Shared aliases for both Macs; duplicated macm5 module | `mact2` is expressly excluded while retaining one shared SSH module. |
| Phone boundary | Document an idempotent, manual `oneplus5` transaction | Pretend it is Nix-managed; automate remote edits | The phone is non-Nix; explicit operator proof is safer and makes drift visible. |

## Data Flow

    public registry ──> peerKeys(target) ──> Linux glats / macm5 juan authorized keys
          │                         │
          ├──> sshSettings(source) ─┴──> Home Manager aliases, local IdentityFile
          └──> oneplus5 runbook ───────> phone glats authorized_keys and aliases

Private keys remain only at their source paths. Alias resolution uses verified LAN endpoints, target account, `IdentitiesOnly = true`, and the *source* identity; it does not weaken host-key checking.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/ssh/lan-mesh.nix` | Create | Public registry, endpoint metadata, peer-key and alias helpers. |
| `linux/system/base/users.nix` | Modify | Import registry and set `glats` keys from `peerKeys config.networking.hostName`. |
| `hosts/macm5/default.nix` | Modify | Supply `host` to Home Manager and set `juan` keys from `peerKeys "macm5"`. |
| `linux/home/ssh.nix` | Modify | Replace mesh-relevant legacy entries with aliases derived for `hostName`; retain unrelated `mact2` convenience alias. |
| `darwin/home/ssh.nix` | Modify | Accept `host`; add aliases only under `host == "macm5"`. |
| `docs/oneplus5-lan-ssh-mesh.md` | Create | Manual inbound synchronization, proof, rollback, drift review, and revocation. |

## Interfaces / Contracts

`shared/ssh/lan-mesh.nix` is an imported Nix interface, not a new option namespace:

```nix
{ lib }:
{
  members = {
    rog = { user = "glats"; publicKey = "..."; comment = "..."; fingerprint = "..."; verifiedOn = "YYYY-MM-DD"; hostName = "..."; identityFile = "id_ed25519_lan"; };
    # thinkcentre, t14, macm5 (juan), oneplus5
  };
  peerKeys = target: /* ordered member keys where name != target */;
  sshSettingsFor = source: /* aliases for every member where name != source */;
}
```

Records MUST be unique `ssh-ed25519` public lines, include owner/account/comment/fingerprint/verification date, and match a locally verified fingerprint before merge. `peerKeys` MUST return no self key. `sshSettingsFor` MUST select `${config.home.homeDirectory}/.ssh/<local identityFile>`, never a target key. The `macm5` system module forwards the existing `host` special argument via `home-manager.extraSpecialArgs`; no global Darwin option changes.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Evaluation | Five records, four peer keys per Nix target, no macm5 self key, no mact2 mesh output | `format-nix` and `nix flake check --no-build`; inspect evaluated aliases/authorized lists. |
| Configuration | Local alias identity, account, endpoint, and `IdentitiesOnly` | On each Nix source, inspect `ssh -G <peer>`; inspect phone aliases manually. |
| Acceptance | All 20 directed non-root connections | Run `ssh -o BatchMode=yes <alias> true` from every source after verified host keys exist; capture redacted results. |
| Revocation | A removed source is rejected everywhere | In a controlled maintenance window remove one registry record, deploy its three Nix peers, manually remove it from oneplus5, terminate practical sessions, and prove rejection; restore only through a newly verified replacement record. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: documentation is not executed or classified. | None. | None. |
| Git repository selection | N/A: no VCS command integration. | None. | None. |
| Commit state | N/A: no commit automation. | None. | None. |
| Push state | N/A: no push automation. | None. | None. |
| PR commands | N/A: no PR automation. | None. | None. |

SSH configuration is the only process-integration surface; it declares client options and invokes no shell/subprocess. Therefore the matrix has no applicable RED-test rows.

## Migration / Rollout

Verify each public line, fingerprint, unique private-key ownership, and LAN endpoint locally before editing. Keep console recovery and known-good Nix generations. Deploy/evaluate Linux targets, then perform native physical `macm5` evaluation and activation, then execute the phone runbook; do not claim completion until the directed matrix passes. Roll back Nix hosts to prior generations and restore the prior documented phone state if rollout fails. Password authentication, root policy, and all `mact2` authorization/aliases remain untouched.

## Open Questions

- [ ] Confirm the canonical LAN endpoint for every member, especially multihomed `t14`.
