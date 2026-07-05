# Apply Progress: t14 SMB Network Visibility

## Slice 1

**Status**: DONE

**Changes**:
- `hosts/rog/services/samba.nix` — Added `services.avahi.extraServiceFiles.smb` with `_smb._tcp` DNS-SD service advertisement (15 lines)

**Verification**:
- `format-nix` — passed
- `nix flake check --no-build` — all hosts passed (rog, thinkcentre, t14)

**Next**: Commit and push, or iterate if changes requested.
