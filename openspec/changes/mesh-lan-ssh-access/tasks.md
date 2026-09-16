# Tasks: LAN SSH Access Mesh

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 180–260 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Public registry and Nix consumers | PR 1 | `nix flake check --no-build` | `ssh -G <alias>` on each Nix source | Revert four Nix files; prior generations remain usable |
| 2 | Phone procedure and acceptance evidence | PR 1 | Manual checklist in runbook | Twenty directed `ssh -o BatchMode=yes <alias> true` checks | Restore documented phone authorized_keys/config |

## Phase 1: Public Registry

- [x] 1.1 Create `shared/ssh/lan-mesh.nix` with exactly the five supplied public `ssh-ed25519` lines, host/account/comment/fingerprint/verification metadata, verified LAN endpoints, and helpers that exclude the target’s own key; store no private or SOPS material.
- [x] 1.2 Add an evaluation check for five unique records and four peers per Nix target; reject duplicate, private, or unverified records before consumer wiring.

Registry literals (public only):
```text
macm5 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGX9n6Xva9Lpuf4Fn4rTqLl+3zbfSN2jzJQW7V54J1mu juan@CLFTCLGV2FHWW0W-lan
rog ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID47wBmPxBXhRq8uxOABpd+G72Gyizn+hDU/B5Z6xAkT glats@rog-lan
thinkcentre ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSehpAzNhKa87/oag3V60HqcmO4/ix6IbOjyXEQM8s6 glats@thinkcentre-lan
t14 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILjmQmDCgrLLPpd9dpvWnB2Uqi25kTvj9Bycp0rKQt+R glats@t14-lan
oneplus5 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAg7nR2ugN5GproFRCXSC2LcoLfn00e1vFUYbBXj/zvD glats@oneplus5-lan
```

## Phase 2: Declarative Nix Wiring

- [x] 2.1 Modify `linux/system/base/users.nix` to import the registry and derive `glats` authorization from `peerKeys`, without changing password or root policy.
- [x] 2.2 Modify `hosts/macm5/default.nix` to derive `juan` authorization, pass the existing `host` special argument, and leave unrelated Darwin behavior unchanged.
- [x] 2.3 Modify `linux/home/ssh.nix` to derive `rog`, `thinkcentre`, `t14`, and `macm5` peer aliases with target users, local source identities, `IdentitiesOnly`, and host-key verification.
- [x] 2.4 Modify `darwin/home/ssh.nix` to accept `host` and emit mesh aliases only for `macm5`; prove `mact2` receives none.

## Phase 3: Manual Phone Boundary

- [x] 3.1 Create `docs/oneplus5-lan-ssh-mesh.md` with idempotent manual enrollment of the four Nix public keys for `glats`, four local-identity peer aliases, permissions, redacted evidence, drift comparison, and rollback; explicitly state oneplus5 is not Nix-managed.
- [x] 3.2 Document emergency revocation: remove the source record and deploy all Nix peers, manually remove it on oneplus5, end practical sessions, prove rejection, then restore only with a newly verified key.

## Phase 4: Verification Matrix

- [x] 4.1 Run `format-nix && nix flake check --no-build`; inspect evaluated authorized-key lists and `ssh -G` for all Nix aliases.
- [ ] 4.2 On physical `macm5`, perform native evaluation/activation, verify Remote Login and `ssh localhost true`, then record redacted evidence.
- [ ] 4.3 Execute and record all twenty source→peer connections (`rog`, `thinkcentre`, `t14`, `macm5`, `oneplus5` × four peers) with designated identities and `BatchMode=yes`.
- [ ] 4.4 Execute the controlled revocation drill and verify the removed key is rejected by every affected target.
