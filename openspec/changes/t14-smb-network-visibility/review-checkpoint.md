# Review Checkpoint: t14 SMB Network Visibility

**Slice**: 1
**Phase**: apply
**Verdict**: APPROVED

**Guard lines**:
```
Rework level: none
Iteration decision needed: Yes
```

## Changes in this slice

Single-file change to `hosts/rog/services/samba.nix` (+15 lines):
- Added `services.avahi.extraServiceFiles.smb` with `_smb._tcp` XML service file
- Published via Avahi DNS-SD on port 445

## Verification

- `format-nix` — passed
- `nix flake check --no-build` — passed (all hosts)

## Pending

- Awaiting user review verdict (approved / changes-requested)
- If approved: commit, push, then verify on actual hardware
- If changes-requested: full iteration
