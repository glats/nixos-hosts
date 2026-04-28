# Proposal: Fix Keyring Password Prompt on Every Desktop Session

## Intent

The gnome-keyring module exists with PAM auto-unlock configuration but is never imported by any host. Users experience repeated password prompts when accessing the keyring because:
1. `modules/hardware/keyring.nix` is not included in any host's imports
2. No PAM integration = no automatic keyring unlock at login

## Scope

### In Scope
- Import `modules/hardware/default.nix` in `hosts/rog/default.nix`
- Import `modules/hardware/default.nix` in `hosts/thinkcentre/default.nix`
- Remove conflicting `SSH_AUTH_SOCK` environment variable from `keyring.nix`
- Validate with `nix flake check`

### Out of Scope
- Changes to keyring configuration beyond import fix
- GPG agent configuration changes (already working in `users.nix`)
- Hardware configuration modifications

## Capabilities

### New Capabilities
- `keyring-auto-unlock`: PAM-integrated automatic gnome-keyring unlock on login

### Modified Capabilities
- None (pure configuration fix)

## Approach

1. Modify `modules/hardware/keyring.nix` to remove line 21 (`SSH_AUTH_SOCK` environment variable) — it conflicts with gpg-agent SSH auth socket configured in `users.nix`
2. Add `../../modules/hardware/default.nix` to imports list in `hosts/rog/default.nix`
3. Add `../../modules/hardware/default.nix` to imports list in `hosts/thinkcentre/default.nix`
4. Run `nix flake check` to validate syntax
5. Run `format-nix` to ensure consistent formatting

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/rog/default.nix` | Modified | Add hardware/default.nix import |
| `hosts/thinkcentre/default.nix` | Modified | Add hardware/default.nix import |
| `modules/hardware/keyring.nix` | Modified | Remove SSH_AUTH_SOCK conflict line |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| SSH agent forwarding conflict | Low | gpg-agent already handles SSH; removing SSH_AUTH_SOCK prevents double-binding |
| PAM service not triggering unlock | Low | All relevant PAM services (login, xrdp-sesman, sshd) already configured in keyring.nix |
| Build failure | Low | Run `nix flake check` before commit |

## Rollback Plan

1. Revert the import additions in both host files
2. Revert the SSH_AUTH_SOCK removal in keyring.nix
3. Run `nixos-rebuild switch` to restore previous state

## Dependencies

- None (all changes are within this repo)

## Success Criteria

- [ ] `nix flake check` passes without errors
- [ ] `hosts/rog/default.nix` imports `modules/hardware/default.nix`
- [ ] `hosts/thinkcentre/default.nix` imports `modules/hardware/default.nix`
- [ ] `modules/hardware/keyring.nix` no longer sets `SSH_AUTH_SOCK`
- [ ] Keyring unlocks automatically after user login (manual verification)
