# Apply Progress: Harden macm5 Apple Silicon Onboarding

## Status

- Change: `harden-macm5-apple-silicon-onboarding`
- Apply state: ready
- Delivery: `size:exception` accepted by maintainer
- Work unit: confirmed corporate identity correction

## Completed Tasks

- [x] 5.1 Decouple the logical Darwin configuration selector from the physical hostname; configure `juan`; preserve `CLFTCLGV2FHWW0W` by omitting `networking.hostName`.
- [x] 5.2 Default Darwin `nixos-build` to `macm5`; document `NIXOS_DARWIN_HOST`; add focused resolver tests.
- [x] 5.3 Use `primaryUser` for the Darwin profile PATH; keep GitHub identity explicitly `jcuzmar`; update onboarding artifacts.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `go -C pkgs/nixos-scripts test ./...` passed; `internal/nixbuild` passed. |
| Runtime harness command/scenario and exact result | Native macm5 activation is not run from Linux; target evaluations passed for `aarch64-darwin`, primary user `juan`, and standalone Home Manager user `juan`. |
| Rollback boundary | Revert the selector/user/identity changes in `lib/mkDarwinHost.nix`, `flake.nix`, macm5/Darwin Home modules, resolver files, docs, and SDD artifacts; no activation or secret changes were made. |

## Verification

- `format-nix` completed successfully.
- `nix flake check --no-build` passed; incompatible Darwin systems were omitted by the Linux check.
- Target evaluation confirmed `aarch64-darwin`, `juan`, and `juan` for macm5 system and standalone Home Manager users.

## Additional Remote-Safe Fix

- Removed the broken Homebrew `vnc-viewer` cask alias and the redundant RealVNC remote launchers; TigerVNC launchers remain configured.
- `format-nix && nix flake check --no-build` passed. No activation or secret access was performed.

## Remaining Tasks

- Native acceptance and evidence remain pending: tasks 1.1-1.3, 2.2, 3.1-3.3, and 4.1-4.2.
