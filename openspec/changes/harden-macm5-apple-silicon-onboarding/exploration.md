## Exploration: harden-macm5-apple-silicon-onboarding

### Current State
`macm5` is already a registered `aarch64-darwin` configuration that closely mirrors the active Intel `mact2` host: it composes nix-darwin, Determinate Nix, Home Manager, nix-homebrew, sops-nix, SSH/Screen Sharing, wsdd, and the sing-box private-link client. It correctly selects `/opt/homebrew/bin` and excludes the unsupported `wkhtmltopdf` package on Apple Silicon. The current `nix.enable = false` plus `determinateNix.customSettings` ownership boundary matches current official Determinate guidance: Determinate manages Nix, its daemon, and `/etc/nix/nix.conf`, while nix-darwin manages macOS ([Determinate guide](https://docs.determinate.systems/guides/nix-darwin/); [nix-darwin manual](https://nix-darwin.github.io/nix-darwin/manual/index.html)).

The stack nevertheless has onboarding gaps. `darwin/system/cachix.nix` and `shared/cachix.nix` set `nix.settings`, which is inactive when `nix.enable = false`; cache URLs and trust keys must instead reach `determinateNix.customSettings`. `darwin/system/sing-box-link.nix` still consumes the `uuid_mact2` credential and identifies the link as mact2-specific, so a new machine would share an old device identity rather than receive a dedicated macm5 credential. The migration runbook predates the current scaffold, is not fully aligned with the repository's present SOPS layout, and does not contain a deterministic first-boot/rollback checklist.

Official and community evidence supports retaining Determinate Nix. Determinate documents `determinateNix.customSettings` as the supported declarative route to `/etc/nix/nix.custom.conf` and warns against editing generated `nix.conf` ([Determinate Nix documentation](https://docs.determinate.systems/determinate-nix/)). Its current nix-darwin guidance supports the installed module and the `nix.enable = false` boundary. Known onboarding failures are concrete: Apple Silicon installations have reported a missing daemon socket and missing `darwin-rebuild` PATH ([LnL7/nix-darwin#1544](https://github.com/nix-darwin/nix-darwin/issues/1544)), empty per-user profiles after initial activation ([LnL7/nix-darwin#1254](https://github.com/nix-darwin/nix-darwin/issues/1254)), and `/nix` APFS mount failures after a macOS update when the installer/distribution state is mixed ([DeterminateSystems/nix-installer#1261](https://github.com/DeterminateSystems/nix-installer/issues/1261)). These reports justify explicit checks and recovery guidance, not a switch away from Determinate.

### Affected Areas
- `hosts/macm5/default.nix` — retain host-specific Apple Silicon configuration, add only macm5-specific onboarding assertions or settings that cannot safely remain shared.
- `lib/mkDarwinHost.nix` — verify the Determinate module boundary against its pinned version and make host-specific inputs available only if hardening needs them.
- `darwin/system/nix.nix` — move all Darwin daemon settings into the Determinate-supported path and make the build/concurrency policy appropriate for the M5 instead of describing an Intel-only constraint.
- `darwin/system/cachix.nix` and `shared/cachix.nix` — refactor cache substituters and trusted keys so Determinate actually applies them without changing Linux behavior.
- `darwin/system/sing-box-link.nix`, `linux/system/services/network/sing-box-link.nix`, `hosts/rog/secrets.nix`, `.sops.yaml`, and `secrets/shared/link-uuids.yaml` — provision and consume a separate macm5 link credential, update server-side identity metadata, and re-encrypt only the necessary ciphertext. Secret plaintext must never enter the change.
- `darwin/system/settings.nix` and `darwin/home/remote-desktop.nix` — remove mact2-only operational assumptions and ensure macm5 remote-access onboarding can be validated without retiring mact2.
- `docs/macm5-migration.md` and `docs/sops-new-host.md` — replace the stale bootstrap instructions with an English, ordered runbook covering prerequisites, first switch, validation, rollback, and the APFS/daemon/PATH recovery checks.
- `flake.nix`, `flake.lock`, `lib/packages.nix`, and `darwin/home/packages.nix` — preserve the already-correct aarch64 registration and package guard; change them only if native macm5 evaluation identifies a pinned-input or package-platform incompatibility.

### Approaches
1. **Targeted onboarding hardening with Determinate retained** — Correct the Determinate configuration boundary, give macm5 its own link identity, and add a native-Mac bootstrap/verification/rollback runbook while preserving mact2 and the current 26.05 pins.
   - Pros: Matches official Determinate guidance; addresses the verified inactive cache configuration and credential-reuse gap; minimizes fleet-wide risk; provides a recoverable physical-device procedure.
   - Cons: Requires an Apple Silicon Mac for final activation proof and SOPS re-encryption; leaves the eventual Intel retirement/channel upgrade as a separate change.
   - Effort: Medium.

2. **Replace Determinate with upstream Nix during onboarding** — Let nix-darwin manage the Nix daemon and all `nix.settings` directly.
   - Pros: Removes the two-owner configuration boundary and reduces adaptation work for existing Nix modules.
   - Cons: Contradicts the requested preference and official support path; forfeits Determinate's macOS integration; introduces an installer migration while provisioning a new machine; does not solve the per-device credential or native-evaluation gaps.
   - Effort: High.

### Recommendation
Adopt Approach 1 as a bounded hardening change. Keep Determinate Nix installed via its macOS package and retain `nix.enable = false`; consolidate every required daemon setting, including cache configuration, into `determinateNix.customSettings`, because that is the only configuration file Determinate supports for custom Nix settings. Do not update nixpkgs/nix-darwin or retire mact2 in this change.

The implementation should create a distinct `uuid_macm5` secret and server-side link identity before activation, then run the first switch natively on macm5. The runbook should require: Xcode command-line tools; a fresh Determinate-only installation (no mixed upstream installer state); the local hostname `macm5`; SOPS host identity and ciphertext re-encryption; a pre-switch native evaluation; post-switch checks for `/nix` mount, `systems.determinate.*` launchd services, Nix/`darwin-rebuild` PATH, Home Manager profile, Homebrew arm64 path, SSH/Screen Sharing, wsdd, and the link in its safe direct-default state. It should state a rollback route using the prior darwin generation and a stop-and-recover rule for APFS mounting or daemon-socket failures.

### Risks
- A Linux host cannot prove the complete aarch64-darwin Home Manager activation; final evidence must be captured on macm5 or an Apple Silicon remote builder.
- Editing `nix.settings` while `nix.enable = false` creates silent configuration drift; merging cache values into `determinateNix.customSettings` must preserve all existing substituters and public keys.
- Reusing `uuid_mact2` would make two devices indistinguishable to the private-link server and complicate independent revocation; adding `uuid_macm5` requires carefully scoped SOPS rule changes and ciphertext rotation.
- A mixed upstream-Nix/Determinate installation or a failed APFS `/nix` mount can block the initial switch; the runbook must stop before activation and use the documented installer recovery path rather than layering another installer.
- Existing macOS activation scripts assume stock launchd labels and may be sensitive to future macOS releases; validate them on the actual M5 before changing mact2 or shared remote-access records.

### Ready for Proposal
Yes — propose a macm5-only, Determinate-first onboarding hardening change with explicit host scope (`macm5` and the rog-side private-link/SOPS records), no mact2 retirement, no channel upgrade, and native-Mac verification as a release gate.
