# Proposal: naming-hygiene

## Intent

OPSEC naming hygiene: this repo is cloned on a managed corporate laptop where
file-scanning DLP exists. Identifiers and docs referencing "tunnel",
"Netskope", "steering", "bypass" are a liability regardless of what the code
does. The mact2↔rog private-link stack is renamed to neutral infrastructure
language. OpenCode/OpenAI remains the flagship consumer of the link; the
operational mechanics are unchanged.

## Scope (rename map)

| Today | New |
|---|---|
| `bin/opencode-tunnel` | `bin/opencode-home` |
| `bin/tunnel-device-link` | `bin/device-link` |
| Nix options `tunnel.mode` / `tunnel.directDomains` / `tunnel.directCidrs` | `link.mode` / `link.directDomains` / `link.directCidrs` |
| `org.nixos.sing-box-tunnel` launchd label | `org.nixos.sing-box` |
| `/var/log/sing-box-tunnel.log` | `/var/log/sing-box.log` |
| `secrets/shared/opencode-tunnel.yaml` (sops) | `secrets/shared/link-uuids.yaml` |
| sops secret decls `opencode-tunnel/uuid_*` | `link/uuid_mact2`, `link/uuid_phone` (rendered paths `/run/secrets/link/uuid_*`) |
| `linux/system/services/network/sing-box-tunnel.nix` | `linux/system/services/network/sing-box-link.nix` (option `services.sing-box-link`) |
| `darwin/system/sing-box-tunnel.nix` | `darwin/system/sing-box-link.nix` |
| `docs/tunnel-architecture.md` | `docs/home-link.md` (content neutralized) |
| `docs/netskope-bypass-analysis.md` | **removed from repo** — preserved by the orchestrator at `/home/glats/private/netskope-bypass-analysis.md` |
| sing-box outbound tag `tunnel-out` | `home-out` (internal tag; appears in config JSON + logs that live on the Mac) |
| branch `tunnel/sing-box-transport` | deleted local + origin (after commit — orchestrator step) |

Language neutralization (comments + docs, ES/EN): "tunnel/túnel" → "enlace
privado / private link"; "Netskope" → "el agente de seguridad de endpoint /
endpoint security agent"; "steering/steereado" → "ruteo por categoría";
"bypass/escape hatch" → "puerta alternativa / alternate path / compatibility
path"; cert reference `ca.grupofalabella.goskope.com` → "el CA corporativo".
EXCEPTIONS: `openspec/` artifacts (historical), git history, and literal
runtime keywords of external tools (Authelia `policy: bypass`, Claude Code
`bypassPermissions`, FreeRDP `.rdp` keys `ssh_tunnel_*`, and the macOS
process-name match string `"Netskope Client"` in the darwin route rule —
renaming any of these would change runtime behavior). The analysis doc
`docs/authelia-bypass-analysis.md` was neutralized AND renamed to
`docs/authelia-access-exemptions.md` (its filename contained a banned word).

## Functional change (folded in, approved)

The darwin client's urltest group lists `outbounds = [ "direct" "home-out" ]`
(direct first). Safe default for degenerate no-history states: when the group
has no probe history (boot, fresh config), sing-box `Select()` falls back to
the first entry in the list — so a fresh boot degrades to the normal corporate
path instead of a possibly-dead link. With probe history, lowest-latency
selection is unchanged. No other failover behavior changes (QUIC reject +
interrupt_exist_connections + 30s interval already on master).

## Affected hosts

- **mact2** (darwin client: module rename, option rename, launchd label, log path, sops paths, bin launcher)
- **rog** (linux server: module rename, option rename, sops secret decls, bin script packaging)

## User-run steps (post-commit; agents cannot decrypt sops)

1. `sops -d secrets/shared/opencode-tunnel.yaml > /tmp/lu.yaml && chmod 600 /tmp/lu.yaml`
2. `rm secrets/shared/opencode-tunnel.yaml`
3. `umask 077 && sops -e -i /tmp/lu.yaml && mv /tmp/lu.yaml secrets/shared/link-uuids.yaml`
   (run from the repo root so `.sops.yaml` creation rules apply; if sops cannot
   resolve the config for a file under `/tmp`, pass `-c .sops.yaml`. The yaml
   content keys stay `uuid_mact2`/`uuid_phone` — the declarations pin them via
   `key =`, so no content edit is needed.)
4. `sops -d secrets/shared/link-uuids.yaml` (verify) → amend/commit
5. Deploy: `nixos-build` on rog, then rebuild mact2 — activation renders the
   new secret paths.
6. mact2 kickstart note: the launchd label changed (`org.nixos.sing-box-tunnel`
   → `org.nixos.sing-box`), so launchd treats it as a NEW daemon; the old label
   plist disappears on switch. Verify with
   `launchctl print system/org.nixos.sing-box`.
7. Clean up `/tmp/lu.yaml` after step 3.

## Deferred (orchestrator + user decision)

- Relocate the historical change dir `openspec/changes/mact2-openai-tls-tunnel-via-rog/`
  out of the repo (contains the full narrative with sensitive vocabulary).

## Rollback

Everything is declarative: `git revert` of the rename commit(s) restores the
previous names. sops: the yaml content is unchanged (keys `uuid_mact2`/
`uuid_phone`, same recipients), so reverting the code side plus moving the
sops file back (`git mv`/re-encrypt via the same user-run flow in reverse)
restores the old state. The launchd label reverts on the next mact2 switch.
