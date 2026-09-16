## Exploration: mesh-lan-ssh-access

### Current State
The three Linux hosts import `linux/system/base/users.nix`, so `glats` has the same two declared authorized public keys on `rog`, `thinkcentre`, and `t14`. All three also enable the shared OpenSSH server module, which permits public-key authentication, forbids root login, but still permits password authentication. Their shared Home Manager SSH configuration already has `oneplus5.local` and `172.16.0.12` entries, both using `${sshDir}/oneplus5`, as well as Linux and mact2 aliases; it does not define a source-specific five-host mesh.

`macm5` is an `aarch64-darwin` configuration with primary user `juan`. It enables the macOS OpenSSH daemon and declares one public key for `juan`; its comment says `t14`, despite describing it as a rog key. `macm5` uses the shared Darwin Home Manager SSH configuration, which has aliases only for `rog.local`, `t14.local`, and the corporate LocalHostName. `mact2` is separately declared and must receive neither mesh authorization nor mesh client aliases. `oneplus5` is a non-Nix LAN host at the existing `.local` name and `172.16.0.12`; its OpenSSH user and authorized-key file must be managed manually on the device.

No public-key files are tracked in this repository. The current declarative key literals are not a sufficient device inventory: two distinct Linux-side public keys are present, while macm5 has one of them, but the repository cannot prove which live host retains which corresponding private key. The oneplus5 source identity is known by comment `glats@oneplus5-lan` and fingerprint `SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc`; its public-key line still has to be supplied to distribute it. Private keys were not accessed.

### Affected Areas
- `linux/system/base/users.nix` — current shared `glats` authorized-key list for all Linux mesh targets.
- `linux/system/networking/openssh.nix` — shared Linux daemon policy; root is already disabled and public-key authentication enabled.
- `linux/home/ssh.nix` — shared Linux client aliases and per-source identity selection.
- `hosts/macm5/default.nix` — `juan`'s declarative authorized-key list.
- `darwin/home/ssh.nix` — macm5 client aliases; it must be scoped so mact2 remains excluded.
- `darwin/system/settings.nix` and `docs/macm5-{migration,acceptance}.md` — physical macm5 Remote Login, launchd, LocalHostName, native acceptance, and rollback constraints.
- `docs/oneplus5-*.md` — existing evidence that oneplus5 is manually operated at `glats@172.16.0.12`; the mesh must add a manual, device-side authorized-key and client-alias procedure without treating it as a Nix target.

### Required Key Inventory
The implementation needs exactly five unique, device-bound `ssh-ed25519` public keys: `rog`, `thinkcentre`, `t14`, `macm5`, and `oneplus5`. Each inventory record must contain the source host, login user (`glats` or `juan`), public-key comment, SHA256 fingerprint, generation/verification date, and the authoritative public-key literal. The oneplus5 record is partially known: comment `glats@oneplus5-lan` and fingerprint `SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc`; its public-key literal remains required. The private key remains only on its source host; it is never copied, stored in this repository, or placed in SOPS.

Each declarative Nix target authorizes the four other source keys: `glats` on the three Linux hosts and `juan` on macm5. On non-Nix oneplus5, the `glats` authorized-keys file must manually authorize the four Nix-host source keys. A source host does not need to authorize its own key. This produces the twenty directed connections below without adding root access:

| Source | Targets |
| --- | --- |
| rog | thinkcentre, t14, macm5, oneplus5 |
| thinkcentre | rog, t14, macm5, oneplus5 |
| t14 | rog, thinkcentre, macm5, oneplus5 |
| macm5 | rog, thinkcentre, t14, oneplus5 |
| oneplus5 | rog, thinkcentre, t14, macm5 |

Before any declarative replacement, collect only each host's public-key fingerprint and public line through an approved local console/session, then compare it with the existing literals. Retain an existing key only when its fingerprint is uniquely owned by the intended source host and its private key is confirmed present and usable there. The misleading macm5 comment and the currently ambiguous ownership mean the existing keys must not be presumed reusable. Generate and distribute a new per-host `ed25519` key only for missing, duplicated, misplaced, or suspected-compromised identities; do not rotate a verified unique key merely to change its comment.

### Approaches
1. **Declarative Nix registry plus explicit oneplus5 procedure** — Add one reviewed Nix public-key registry containing all five source keys and derive the four Nix targets' other-host lists from it. Configure mesh aliases separately in Linux and macm5 Home Manager modules, and document a manual oneplus5 transaction that updates its `glats` authorized keys with the four Nix keys and its client aliases with its local oneplus5 identity.
   - Pros: The Nix fleet remains atomic and auditable; public material only; the manual boundary is explicit instead of pretending oneplus5 is declaratively managed; deletion from the registry and a documented oneplus5 removal step provide a complete revocation path.
   - Cons: oneplus5 is a mandatory manual deployment and verification point; it can drift from the registry; raw keys still require fleet-wide removal for emergency revocation.
   - Effort: Medium.

2. **Manually maintain each host's authorized_keys and SSH config** — Copy the four peer public keys to each destination and edit aliases independently.
   - Pros: No configuration refactor.
   - Cons: Drift-prone, difficult to audit/revoke, conflicts with the repository's declarative pattern, and can leave stale keys after handover or rotation.
   - Effort: Medium initially, High over time.

3. **Introduce an SSH certificate authority or dynamic AuthorizedKeysCommand** — Trust a CA or look up keys at connection time.
   - Pros: Centralized lifecycle and potentially stronger expiry/revocation at larger fleet scale.
   - Cons: Adds signing or availability infrastructure, recovery complexity, and new private trust material for only five hosts; disproportionate to the request.
   - Effort: High.

### Recommendation
Adopt Approach 1. Keep the current user-level account boundary: `glats` on `rog`, `thinkcentre`, `t14`, and oneplus5; `juan` on physical `macm5`; no `root` authorization. Store all five public `ssh-ed25519` lines in one reviewed declarative registry, use it to authorize every other source on each Nix target, and treat oneplus5 as a separately executed manual synchronization step. The public key with the supplied oneplus5 fingerprint must be matched to its full public-key line before it enters either location. Do not place a `restrict` option on these interactive administration keys: OpenSSH `restrict` disables PTY and forwarding, which would break normal interactive SSH and legitimate operator tunnels. Least privilege instead comes from per-device keys, named non-root accounts, `PermitRootLogin = no`, no shared private keys, and no mact2 membership. Password-authentication hardening is a separate compatibility decision and is not required to create this mesh.

Use stable aliases `rog`, `thinkcentre`, `t14`, `macm5`, and `oneplus5`, resolving to verified LAN `.local` names or pinned LAN addresses. Each alias MUST set the target account and `IdentitiesOnly yes`; its `IdentityFile` MUST name the local source-host key, not the target. The existing Linux oneplus5 aliases select `${sshDir}/oneplus5`; retain them only if that file is the unique local source identity and its fingerprint is inventoried, otherwise replace them with per-source mapping. oneplus5 itself needs manually maintained aliases for the four Nix targets using its own local identity. Do not weaken host-key verification or enable host-key acceptance automatically. Make Linux aliases available through the existing shared Linux Home Manager module. Scope Darwin aliases specifically to macm5 so mact2 does not acquire mesh behavior; this may require explicitly passing a host identifier into the Darwin Home Manager module rather than relying on the shared file alone.

Revocation is registry removal and deployment to every Nix target that authorized the key, plus the same manual removal from oneplus5 when applicable. The proposal should require an emergency procedure: remove the compromised source key from all four peer target lists, activate the Nix targets, apply and verify the oneplus5 edit, terminate any active sessions authenticated by it where practical, verify rejection from the affected client, and only then generate/distribute a replacement public key. An OpenSSH `@revoked` entry or `RevokedKeys` file may provide defense in depth, but removal from the Nix allow lists and oneplus5's manual allow list is the required operational mechanism. Scheduled fingerprint inventory review, manual oneplus5 drift checks, and removal of macm5's key when it is handed over are mandatory lifecycle steps.

Physical macm5 prerequisites are: a native `aarch64-darwin` evaluation and dry activation, a known-good generation for rollback, a healthy Determinate installation and `/nix` mount, the company-controlled LocalHostName preserved, `com.openssh.sshd` running, and a local `ssh localhost true` proof. The mesh must be activated and tested on the physical Mac; evaluation from Linux cannot prove macOS launchd, LAN reachability, or the local private identity. Existing macm5 acceptance requires redacted evidence and does not authorize any mact2 retirement change.

### Risks
- Replacing the current lists before fingerprinting can remove the only working route or authorize a key whose source/owner is misidentified.
- macm5's physical activation is the availability boundary; a remote-only evaluation cannot validate its account, daemon, mDNS, firewall, or keychain/agent behavior.
- The active Linux SSH server still allows passwords. Disabling that fallback without a console recovery path is a separate breaking hardening change.
- `t14.local` has a documented multi-NIC/mDNS history; validate the canonical LAN address from every source before relying on aliases.
- oneplus5 is outside Nix deployment, so a failed or omitted authorized-keys update leaves the mesh partial and makes revocation incomplete until the device-side change is verified.
- The supplied oneplus5 fingerprint identifies the key but cannot be distributed until its complete public-key line is inventoried and matched.
- Existing sessions survive public-key removal; an incident response needs session termination in addition to configuration deployment.

### Sources
- Context7: [NixOS SSH configuration manual](https://github.com/nixos/nixpkgs/blob/master/nixos/doc/manual/configuration/ssh.section.md) and `sshd.nix` — `users.users.<name>.openssh.authorizedKeys.keys` is declarative public-key input; `PermitRootLogin = "no"` is supported.
- Context7: [OpenSSH portable](https://github.com/openssh/openssh-portable) — `restrict` disables PTY and forwarding; `from` and `expiry-time` are available key options.
- GitHub: [nix-darwin #674](https://github.com/nix-darwin/nix-darwin/issues/674) — validate the generated macOS `AuthorizedKeysFile` behavior rather than assuming its path.
- Exa: [OpenSSH authorized_keys(5)](https://manpages.debian.org/bookworm/openssh-server/authorized_keys.5.en.html) — key options, `@revoked`, file permissions, and `StrictModes` behavior.
- Repository: `linux/system/base/users.nix`, `linux/system/networking/openssh.nix`, `linux/home/ssh.nix`, `hosts/macm5/default.nix`, `darwin/home/ssh.nix`, `docs/macm5-migration.md`, and `docs/oneplus5-{adguard-dns,wifi-watchdog}.md`.

### Ready for Proposal
Yes — after an operator supplies the complete public-key lines and confirms unique ownership for all five source hosts, including a line matching oneplus5 fingerprint `SHA256:hZLmKIISKxNV4jaHR1yhKuUQ/Zknq7AvT6SZ7xCjVGc`. The proposal should define the registry, Nix target-derived authorization lists, oneplus5's reviewed manual authorized-keys/client-alias procedure, macm5-only client aliases, a twenty-direction acceptance matrix, an explicit emergency revocation drill that includes oneplus5, and redacted physical-Mac/oneplus5 evidence. No production configuration was changed by this exploration.
