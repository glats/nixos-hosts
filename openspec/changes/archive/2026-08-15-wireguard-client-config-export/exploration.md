# Exploration: WireGuard client config export to ~/Documents

## Current State

- `linux/system/services/network/wireguard.nix` is imported ONLY by `hosts/rog/default.nix` (line 79). Verified: no other host imports it. macOS `darwin/home/packages.nix` installs `wireguard-tools` for *client* use — unrelated.
- The module uses `system.activationScripts.wireguard-client-configs` to generate, at every activation/boot, `/etc/wireguard/clients/<name>.conf` for each of 5 peers (`peers` attrset: oneplus9, mac, thinkpad, samsung, thinkphone). Files are root-owned, `chmod 600`, contain the server pubkey, the peer PSK in plaintext, and a commented-out client PrivateKey (client keys are generated client-side).
- `SERVER_PUB` is derived at runtime via `${wgTools}/bin/wg pubkey < server_private_key.path`; PSKs read from `config.sops.secrets."wireguard/peer_*_psk".path` (decrypted at activation by sops-nix).
- User `glats`: home `/home/glats` (users.nix). Repo convention for root-activation ownership fixes is hardcoded `glats:users` (droppy.nix, arr-stack.nix). Primary group is `users`.
- `xdg-user-dirs` is installed (profiles/core.nix) so `~/Documents` usually exists after first login, but activation may run before login → `mkdir -p` is mandatory.
- Secrets declared in `hosts/rog/secrets.nix` (sops), no owner/group/mode override → default root:root 0400, read fine by the root activation script.

## Affected Areas

- `linux/system/services/network/wireguard.nix` — the activationScript to extend with an export step.
- (Optional, out of scope) `/etc/wireguard/clients/` itself is never pruned of stale peer configs — pre-existing gap.
- Legacy `bin/add-wireguard-peer`, `bin/remove-wireguard-peer`, `bin/generate-thinkpad-wireguard` reference pre-refactor paths — stale, out of scope.

## Approaches

1. **Extend existing `system.activationScripts.wireguard-client-configs`** — add an export block after the existing generation: `mkdir -p`, `install` each `.conf` into `/home/glats/Documents/wireguard/`, prune stale, ownership `glats:users` mode 600.
   - Pros: minimal (a few lines in the file that already owns this logic); always fresh (regenerated on every `nixos-rebuild switch`/boot — activationScript contract is "idempotent and fast"); no new packages (`install` is coreutils); single source of truth (peers attrset); no ordering hazard.
   - Cons: hardcodes username/group (repo already does this in droppy/arr-stack); writes into home from root (needs explicit chown).
   - Effort: Low

2. **Standalone `bin/` script that copies on demand** — new script user runs manually.
   - Pros: user-controlled timing; no activation side effects.
   - Cons: manual step that will be forgotten → stale exports; adds to the already-stale `bin/` wireguard scripts; not declarative.
   - Effort: Low (but adds moving part + docs)

3. **Home Manager `home.file`** — declare files in HM.
   - Cons: fundamentally incompatible — configs contain runtime-decrypted PSK (must NOT be baked into world-readable /nix/store); `home.file.source` to a 600 root file is unreadable via symlink; HM vs system activation ordering is fragile. REJECT.
   - Effort: Medium (and wrong)

4. **systemd tmpfiles** — `C+` copy rules into home.
   - Cons: tmpfiles copies static content, can't derive `SERVER_PUB` or read secrets; adds a second mechanism for zero benefit. REJECT.
   - Effort: Medium

## Recommendation

**Approach 1 — extend the existing activationScript.** After the current `chmod 600 /etc/wireguard/clients/*` line, add:

```bash
DOCS_DIR=/home/glats/Documents/wireguard
mkdir -p "$DOCS_DIR"
install -o glats -g users -m 600 /etc/wireguard/clients/<name>.conf "$DOCS_DIR/<name>.conf"   # per peer
# prune stale configs whose peer was removed
cd "$DOCS_DIR" && for f in *.conf; do [ -f "$f" ] || continue; case "$f" in <expected>|... ) ;; *) rm -f "$f" ;; esac; done
```

The expected-filename list is generated at eval time from `builtins.attrNames peers` (same `mapAttrsToList` loop already used). Ownership via `install -o glats -g users -m 600` (single idempotent command, matches repo convention). Files 600 (contain PSK). No new option/`enable` gate needed — module is already imported only by `rog`.

## Risks

- Stale configs in `/etc/wireguard/clients/` (not pruned today) can mask peer removal; export pruning only fixes the copy — consider also pruning `/etc` in the same change (small, optional).
- `~/Documents` may not exist if xdg-user-dirs hasn't run → handled by `mkdir -p`.
- Hardcoded `glats:users` is a magic string; derive from `config.users.users.glats` if the module is ever reused on a multi-user host. Acceptable today.
- Root writing into `/home` is safe here (local disk), but could fail if home were ever on a separate mount — not the case for rog.

## Ready for Proposal

Yes. Proceed to `sdd-propose`. Scope: single file (`wireguard.nix`), single host (`rog`), no new packages.
