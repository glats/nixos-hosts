# Proposal: LAN SSH Access Mesh

## Intent

Provide bidirectional, user-level LAN SSH access among `rog`, `thinkcentre`, `t14`, `macm5`, and non-Nix `oneplus5` with unique source-host ed25519 identities. The mesh replaces ambiguous shared authorization with an auditable public inventory while preserving the current password-authentication policy.

## Scope

### In Scope
- Add a public-only registry for five source identities, including owner, account, public line, comment, fingerprint, and verification date.
- Declaratively authorize every peer key on Nix targets: `glats` on Linux and `juan` on `macm5`; never authorize a source's own key.
- Add host-specific aliases for all five members, each using the local source identity and `IdentitiesOnly`.
- Document manual `oneplus5` inbound authorization and revocation; verify all twenty directed connections, physical `macm5` activation, and an emergency revocation drill.

### Out of Scope
- `mact2`, root SSH access, shared private keys, SOPS key storage, SSH certificates, and automatic host-key acceptance.
- Changing `PasswordAuthentication` or other existing daemon password policy.

## Capabilities

### New Capabilities
- `lan-ssh-mesh`: Declarative Nix-target authorization and aliases, plus documented manual `oneplus5` lifecycle work, for the five-member non-root mesh.

### Modified Capabilities
None.

## Approach

Create one reviewed Nix registry containing only public records. Linux and `macm5` derive peer authorization from it; Home Manager aliases select only the source host's private key. Confirmed Nix records are `macm5` `juan@CLFTCLGV2FHWW0W-lan` (`SHA256:dGchDHoVqgTTvF7PafEYb4aRJaaGYxryV0Cpmq+DQdg`), `rog` `glats@rog-lan` (`SHA256:Q5lpc7wmLtuEQcBMS498KRDzuJiCB8uxiWOtYtptVRw`), `thinkcentre` `glats@thinkcentre-lan` (`SHA256:VxKH+PuTiSwVMeBflQ7RBkT+RFwRC5wWHsw9jEv3L8Q`), and `t14` `glats@t14-lan` (`SHA256:rkMW1xYiWF9TRp8bR1lWWlm7axKlPOtF41bFFpTZQfU`). Add `oneplus5` `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAg7nR2ugN5GproFRCXSC2LcoLfn00e1vFUYbBXj/zvD glats@oneplus5-lan` (`SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc`). On `oneplus5`, add the four Nix public keys and remove compromised keys manually.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `shared/ssh/lan-mesh.nix` | New | Public identity registry and peer selection helpers. |
| `linux/system/base/users.nix` | Modified | Linux peer authorization. |
| `hosts/macm5/default.nix` | Modified | `juan` peer authorization. |
| `linux/home/ssh.nix` | Modified | Linux mesh aliases. |
| `darwin/home/ssh.nix` | Modified | `macm5`-only aliases; exclude `mact2`. |
| `docs/oneplus5-lan-ssh-mesh.md` | New | Manual inbound authorization, revocation, and proof for non-Nix `oneplus5`. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Incorrect LAN resolution or macOS activation blocks access | Medium | Test every direction and retain a known-good local generation. |
| `oneplus5` manual state drifts from the registry | Medium | Record its authorized keys and revocation procedure; verify the full matrix after changes. |

## Rollback Plan

Revert registry consumers and aliases, then activate prior generations on affected Nix hosts. For a compromised identity, remove its record from all four peer Nix targets and manually remove it from `oneplus5` where authorized; end practical active sessions before issuing a replacement.

## Dependencies

- Five confirmed public-key literals and verified LAN endpoints; private keys remain solely on their source hosts.
- Native `aarch64-darwin` evaluation and activation on physical `macm5`.

## Success Criteria

- [ ] Each of the twenty peer-to-peer non-root SSH connections authenticates with its designated local key.
- [ ] `mact2` and root receive neither mesh authorization nor aliases, and password-authentication policy is unchanged.
- [ ] Nix targets declaratively authorize `oneplus5`; its inbound authorization and revocation are documented and manually proven.
- [ ] Removing a registry record and deploying peer targets, plus manual removal on `oneplus5`, rejects that source key.
