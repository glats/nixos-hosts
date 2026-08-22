# Delta for wireguard-config-export

## REMOVED Requirements

### Requirement: On-demand export of client configs

(Reason: superseded by wg-easy's web UI, which provides native config download + QR.)
(Migration: distribute client configs via `https://wg.glats.org` UI.)

### Requirement: Idempotent overwrite

(Reason: superseded by wg-easy's native download.)
(Migration: None — the behavior no longer exists.)

### Requirement: Stale-file pruning

(Reason: superseded by wg-easy's native download.)
(Migration: None.)

### Requirement: Missing or empty source safety

(Reason: superseded by wg-easy's native download.)
(Migration: None.)

### Requirement: sudo failure handling

(Reason: superseded by wg-easy's native download.)
(Migration: None.)

### Requirement: Script registration

(Reason: `bin/export-wireguard-configs` is removed along with its `pkgs/nixos-scripts` registration.)
(Migration: None.)
