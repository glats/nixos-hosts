# macm5 Apple Silicon onboarding

Use this runbook to prepare and natively accept `macm5` (`aarch64-darwin`).
Complete the remote-safe checks first, then perform the native checks on the
physical Mac. Native acceptance is not recorded by this document: complete
`docs/macm5-acceptance.md` and obtain maintainer approval before any retirement
change.

## Quick path

1. Run the remote-safe checks from Linux.
2. Prepare a fresh Determinate-only macm5 installation.
3. Run the first evaluation and switch on macm5.
4. Complete every native acceptance check and record redacted evidence.
5. Stop on any installer, APFS, or daemon-socket failure; recover macm5 before
   continuing.

## Safety boundary

The existing Intel Darwin configuration and its private-link records remain
unchanged until native macm5 acceptance is approved. This runbook does not use
that host as a validation target, fallback, or rollback path. Recovery uses
only the macm5 Git state and a known-good macm5 generation.

Do not decrypt secrets, print UUIDs, add a guessed UUID, or commit plaintext
credentials. The dedicated `uuid_macm5` identity is provisioned separately by
an authorized SOPS operator; this runbook only verifies that the required
ciphertext is available to macm5.

## Phase 1: remote-safe preparation

Run from the repository on Linux:

```text
cd ~/.nixos
format-nix
nix flake check --no-build
nix eval --raw '.#darwinConfigurations.macm5.pkgs.stdenv.hostPlatform.system'
git diff --check
```

Confirm that the platform evaluation returns `aarch64-darwin`. These checks
prove configuration evaluation only; they do not prove activation, APFS,
launchd, Home Manager, Homebrew, remote access, or private-link behavior.

## Phase 2: native prerequisites

On the physical Mac, complete this checklist before the first switch:

- [ ] Finish macOS setup and set LocalHostName to `macm5`.
- [ ] Install Xcode Command Line Tools.
- [ ] Install Nix with Determinate from a fresh base; do not layer it over
      another Nix installer or install a second daemon to repair a mixed state.
- [ ] Confirm that `/nix` is mounted and writable by Determinate.
- [ ] Confirm the Determinate daemon socket and launchd services are healthy.
- [ ] Complete the authorized host-recipient and link-identity steps in
      `docs/sops-new-host.md`; keep ciphertext opaque.

If the installer state is mixed, `/nix` is not mounted, or the daemon socket is
missing, stop. Record the failure and repair the Determinate installation
before evaluating or switching macm5. Do not proceed to retirement work.

## Phase 3: first evaluation and switch

After the native prerequisites pass, run on macm5:

```text
cd ~/.nixos
nix eval --raw '.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath'
nix eval --raw '.#homeConfigurations.macm5.activationPackage.drvPath'
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.nixos#macm5
```

The Darwin configuration keeps `nix.enable = false`; Determinate remains the
sole Nix owner. Daemon and cache settings are emitted through
`determinateNix.customSettings`, not `nix.settings`.

After this first successful switch, use the installed wrapper for later changes:

```text
nixos-build dry
nixos-build switch
```

## Phase 4: native acceptance

Complete `docs/macm5-acceptance.md` with redacted command results, timestamps,
the Git revision, and the resulting macm5 generation. An operator and a
maintainer must approve the record. Any unchecked item fails the gate.

Run the command checks below on macm5:

```text
test "$(uname -m)" = arm64
test "$(scutil --get LocalHostName)" = macm5
mount | grep ' /nix '
launchctl print system/systems.determinate.nix-daemon
command -v nix
command -v darwin-rebuild
which brew                         # must resolve under /opt/homebrew/bin
home-manager generations
ssh localhost true
launchctl print system/com.openssh.sshd
launchctl print system/com.apple.screensharing
wsdd --version                     # or the deployed wsdd service check
sing-box check -c /run/secrets/rendered/sing-box.json
stat -f '%Su %Lp' /run/secrets/rendered/sing-box.json
linkctl status
```

Also verify the following behavior:

- [ ] `/opt/homebrew/bin` is in the system PATH.
- [ ] Home Manager activation succeeded.
- [ ] SSH and Screen Sharing are reachable from the approved network.
- [ ] wsdd advertises `macm5`.
- [ ] The rendered sing-box configuration is root-owned and mode `0400`.
- [ ] Private and corporate CIDRs remain direct.
- [ ] The private link uses the safe direct default before probe history exists.
- [ ] Link failure leaves ordinary corporate connectivity usable.

The acceptance record must contain no UUID values or decrypted secret data.
Record only redacted success/failure evidence and references to the encrypted
secret and generation.

## Recovery

Before each native switch, record the current Git revision and generation:

```text
git rev-parse HEAD
darwin-rebuild --list-generations
```

For a failed activation, return to the last known-good macm5 generation:

```text
darwin-rebuild --rollback
```

If the generation is unavailable, restore the reviewed macm5 Git revision and
run `nixos-build dry` before switching again. APFS and daemon-socket failures
are stop conditions, not reasons to remove configuration or identity records.

## Retirement gate

Retirement is a separate destructive change. It requires an approved native
acceptance record, explicit authorization, and a fresh review of the exact
diff. Until then, leave existing host declarations, remote-access entries,
server users, and SOPS records unchanged. Never perform retirement as part of
bootstrap recovery.
