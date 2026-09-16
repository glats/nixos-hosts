# Apply Progress: Harden macm5 Apple Silicon Onboarding

## Status

- Change: `harden-macm5-apple-silicon-onboarding`
- Apply state: ready
- Delivery: `size:exception` accepted by maintainer
- Work unit: evidence-gated macm5-only Darwin retirement

## Completed Tasks

- [x] 5.1 Decouple the logical Darwin configuration selector from the physical hostname; configure `juan`; preserve `CLFTCLGV2FHWW0W` by omitting `networking.hostName`.
- [x] 5.2 Default Darwin `nixos-build` to `macm5`; document `NIXOS_DARWIN_HOST`; add focused resolver tests.
- [x] 5.3 Use `primaryUser` for the Darwin profile PATH; keep GitHub identity explicitly `jcuzmar`; update onboarding artifacts.
- [x] 2.2 Stage the macm5 link identity declarations and recipient scope without modifying mact2 or encrypted ciphertext.
- [x] 3.1 Keep macm5 as the only Darwin onboarding target, preserving `juan`, arm64 Homebrew, direct-default routing, and native remote access.
- [x] 3.3 Record accepted native evidence: physical macm5 deployed successfully, SOPS decrypted on-host, `linkctl` ran, the local proxy served a public Cloudflare issuer, and rog logged authenticated `[macm5]` VLESS traffic including `example.com`.
- [x] 4.1 After maintainer authorization, remove mact2 outputs, host/configuration, stale remote targets, VLESS user, and public SOPS recipient/rules. The encrypted UUID ciphertext remains untouched pending the documented admin-only procedure.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `go -C pkgs/nixos-scripts test ./...` passed; `nix fmt --` on all changed Nix files passed; `nix flake check --no-build` passed. |
| Runtime harness command/scenario and exact result | Native macm5 evidence accepted by maintainer: deployment succeeded; SOPS decrypted; `linkctl` ran; the local proxy returned a public Cloudflare issuer; rog logged authenticated `[macm5]` VLESS traffic including `example.com`. No secret values were read in this session. |
| Rollback boundary | Revert the Darwin UUID selector, rog declaration/server user, `.sops.yaml` recipient/rules, docs, and SDD artifacts; encrypted ciphertext remains unchanged. |

## Verification

- `nix fmt --` completed for the changed Nix files. The repository-wide `format-nix` run was interrupted while traversing existing worktrees; it did not change encrypted files.
- `nix flake check --no-build` passed; incompatible Darwin systems were omitted by the Linux check.
- Target evaluation confirmed `aarch64-darwin`, `juan`, and `juan` for macm5 system and standalone Home Manager users.

## Additional Remote-Safe Fix

- Removed the broken Homebrew `vnc-viewer` cask alias and the redundant RealVNC remote launchers; TigerVNC launchers remain configured.
- `format-nix && nix flake check --no-build` passed. No activation or secret access was performed.

## Additional Remote-Safe Fix: Flameshot Packaging

- Replaced the unavailable Homebrew `flameshot` cask with nixpkgs `flameshot` in the Darwin Home Manager package set; Homebrew no longer manages Flameshot.
- The change preserves native `aarch64-darwin` packaging and does not add unsigned DMG handling or Gatekeeper bypasses.
- `nix fmt -- darwin/home/packages.nix` completed successfully.
- `nix flake check --no-build` passed.
- `nix eval --impure --raw --system aarch64-darwin --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.aarch64-darwin.flameshot.drvPath'` evaluated `/nix/store/y8n4awdppa44n21lrx2ykh3h0mvcysni-flameshot-13.3.0.drv`.

## Remaining Tasks

- Tasks 1.1-1.3 and 4.2 remain pending; they are harness/verification work, not evidence required to authorize this retirement slice.
- The encrypted link UUID file still requires the documented admin-only removal of `uuid_mact2` followed by recipient re-encryption; this session did not read or modify ciphertext.
