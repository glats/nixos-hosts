# Tasks: naming-hygiene

Review Workload Forecast: mechanical rename + comment neutralization, well
under 400 changed lines of logic; single commit, no chained PRs needed.

## Phase 1: Sensitive doc relocation

- [x] 1.1 Copy `docs/netskope-bypass-analysis.md` to `/home/glats/private/` (dir created) BEFORE removal
- [x] 1.2 `git rm docs/netskope-bypass-analysis.md`

## Phase 2: File renames (git mv, history-preserving)

- [x] 2.1 `bin/opencode-tunnel` → `bin/opencode-home`
- [x] 2.2 `bin/tunnel-device-link` → `bin/device-link`
- [x] 2.3 `linux/system/services/network/sing-box-tunnel.nix` → `sing-box-link.nix`
- [x] 2.4 `darwin/system/sing-box-tunnel.nix` → `sing-box-link.nix`
- [x] 2.5 `docs/tunnel-architecture.md` → `docs/home-link.md`

## Phase 3: Code reference updates

- [x] 3.1 darwin client module: options `tunnel.*` → `link.*` (`link.mode`, `link.directDomains`, `link.directCidrs`); `sops.secrets."opencode-tunnel/uuid_*"` → `"link/uuid_*"` with `sopsFile = secrets/shared/link-uuids.yaml`; placeholders + template `sing-box-tunnel.json` → `sing-box.json`; launchd `sing-box-tunnel` → `sing-box` (command path `/run/secrets/rendered/sing-box.json`, log paths `/var/log/sing-box.log`); outbound tag `tunnel-out` → `home-out` in all rules
- [x] 3.2 darwin client urltest: `outbounds = [ "direct" "home-out" ]` + comment explaining first-in-list-wins-with-no-history (sing-box `Select()` safe default)
- [x] 3.3 linux server module: option `services.sing-box-tunnel` → `services.sing-box-link`; users[].uuid `_secret` paths → `config.sops.secrets."link/uuid_*".path`
- [x] 3.4 `hosts/mact2/default.nix`: import path, `link.directCidrs`, comments neutralized
- [x] 3.5 `hosts/rog/default.nix`: import path, `services.sing-box-link.enable`, comments
- [x] 3.6 `hosts/rog/secrets.nix`: decls `link/uuid_mact2` / `link/uuid_phone`, `sopsFile = ../../secrets/shared/link-uuids.yaml` (yaml content keys stay `uuid_mact2`/`uuid_phone` via `key =`)
- [x] 3.7 `.sops.yaml`: rule `path_regex` → `secrets/shared/link-uuids\.yaml` + comment neutralized
- [x] 3.8 `pkgs/nixos-scripts/default.nix`: install + wrap new bin names
- [x] 3.9 `flake.nix` comment: launcher + stack naming
- [x] 3.10 `bin/opencode-home` header + vars (`LINK_HOST`/`LINK_PORT`), `bin/device-link` header/usage/defaults (`/run/secrets/link/uuid_phone`, `LINK_PHONE_UUID_FILE`, tag `home-out` in SFA JSON)

## Phase 4: Language neutralization (comments + docs)

- [x] 4.1 `docs/home-link.md` — full neutralization, same operational instructions; openspec historical dir referenced without its sensitive name; relocated analysis doc row removed
- [x] 4.2 darwin/linux sing-box modules + bin headers: neutral infra language ("enlace privado"/"private link", "el agente de seguridad de endpoint", "ruteo por categoría", "puerta alternativa"); cert string → "el CA corporativo"
- [x] 4.3 Peripheral comment/doc hits: `nginx.nix` (vhost comment + "Bypass locations"), `wg-peer.md` (×2), `xrdp-session.sh`, `rog-poweroff-workaround.nix` (×3 incl. option description), `flaresolverr.nix`, `arr-stack.nix`, `t14/default.nix`, `thinkfan-ui/default.nix`, `docs/authelia-bypass-analysis.md` (mechanical "bypass" → "direct/exempt" language)

## Phase 5: Change artifacts

- [x] 5.1 `openspec/changes/naming-hygiene/proposal.md` (this change)
- [x] 5.2 `openspec/changes/naming-hygiene/tasks.md`

## Phase 6: Validation

- [x] 6.1 Banned-word sweep: `grep -rniE "tunnel|netskope|steering|bypass|goskope|túnel" --include="*.nix" --include="*.md" --include="*.sh" . | grep -v openspec/ | grep -v ".worktrees"` → zero hits EXCEPT 15 documented runtime keywords of external tools (FreeRDP `.rdp` keys `ssh_tunnel_*` ×11 in `linux/home/remote-desktop.nix`, Authelia `policy: bypass` ×2, Claude Code `"bypassPermissions"` ×1, macOS process-name match string `"Netskope Client"` ×1 in the darwin route rule — renaming any of these would change runtime behavior, violating the identical-behavior constraint)
- [x] 6.2 `bash -n` both renamed bin scripts
- [x] 6.3 `nix build --no-link .#nixosConfigurations.rog.pkgs.nixos-scripts` builds with new names
- [x] 6.4 `nix flake check --no-build` → with a TEMPORARY byte-identical ciphertext copy of the sops file staged at `secrets/shared/link-uuids.yaml` (removed after validation; no decryption), the failure is identical to the pre-existing baseline (GC'd hyprland input `ks1ls6ms4zcbivkb54rly16jf30bqsif-source`). WITHOUT the temp copy, flake check + rog eval fail with `Path 'secrets/shared/link-uuids.yaml' does not exist in Git repository` — the expected state until the USER-RUN sops rename; that error itself proves evaluation resolves the new sops path.
- [x] 6.5 Targeted evals (same temp-copy setup): rog toplevel `drvPath` → `/nix/store/kasl...-nixos-system-rog-26.05...drv` ✓; mact2: `launchd.daemons` = `["activate-system","sing-box","sops-install-secrets","wsdd"]`, `StandardOutPath` = `/var/log/sing-box.log`, `link.directCidrs` = `[ "163.116.0.0/16" ]`, `link.mode` = `"full"`, `sops.secrets` = `["link/uuid_mact2","link/uuid_phone"]`, `sops.templates` = `["sing-box.json"]`; rog: `services.sing-box-link.enable` = true, `sops.secrets` contains `link/uuid_*` ✓. (mact2 toplevel eval remains blocked by the PRE-EXISTING `gentle-ai-assets` x86_64-darwin platform mismatch on Linux host — unchanged from baseline.)
- [x] 6.6 `git status` shows only renames + docs move + artifacts; no stray files

## Phase 7: USER-RUN (orchestrator hands off; NOT agent-executable)

- [ ] 7.1 sops rename flow (proposal.md "User-run steps" 1–4), then commit/push
- [ ] 7.2 Deploy: `nixos-build` on rog, rebuild on mact2 (activation renders new `/run/secrets/link/uuid_*` paths)
- [ ] 7.3 mact2: verify new daemon `launchctl print system/org.nixos.sing-box` (label changed → launchd handles it as a NEW daemon; old label plist disappears on switch; kickstart `-k` after any config change)
- [ ] 7.4 Branch deletion LAST (orchestrator): `git branch -d tunnel/sing-box-transport && git push origin --delete tunnel/sing-box-transport`
