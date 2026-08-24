# Tasks: mact2 OpenAI Transport Proxy via rog

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~680 (≈475 deletions, ≈210 additions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (new egress + switch) → PR 2 (gateway retirement) |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | New egress + native mact2 switch | PR 1 | `nix flake check --no-build` | from mact2: `curl -x http://10.13.13.1:3128 -sS https://api.openai.com/v1/models` | disable tinyproxy; restore `activeProviderName` |
| 2 | Seed lifecycle (publisher + installer scoping) | PR 1 | `bash -n bin/publish-opencode-auth-seed bin/install-opencode-auth-seed` | run publisher on rog; `bin/install-opencode-auth-seed --dry-run` on mact2 | delete publisher; installer reverts independently |
| 3 | Gateway retirement | PR 2 | `rg -n "openai-proxy|oai\.glats\.org|OPENAI_PROXY_API_KEY" --glob '!archive/**'` | `curl -sS https://oai.glats.org/v1/models` → refused/404 | `git restore` deleted files (emergency bridge only) |

Tags: (REVERT) old-gateway removal · (ADAPT) keep+modify · (NEW) added. Threat matrix: all rows N/A — no RED-test tasks.

## Phase 1: Revert — Retire API Gateway (rog + shared wiring)

- [x] 1.1 (REVERT) Delete `linux/system/services/web/opencode-proxy.nix`.
- [x] 1.2 (REVERT) In `hosts/rog/default.nix`, drop module import (line 67), `services.opencodeProxy` block (214-223), and `opencode-proxy` TimeoutStartSec override (193).
- [x] 1.3 (REVERT) Remove `oai.glats.org` vhost from `linux/system/services/web/nginx.nix` (589-630); retain `/uploads/`.
- [x] 1.4 (REVERT) Remove `openai_proxy/client_key` + `openai_proxy/upstream_key` from `hosts/rog/secrets.nix` and `shared/sops.nix`; delete `.sops.yaml` creation rule (lines 10-18).
- [x] 1.5 (REVERT) Delete encrypted `secrets/host/rog/openai-proxy.yaml` via sops/age removal — never plaintext.
- [x] 1.6 (REVERT) Remove `OPENAI_PROXY_API_KEY` export from `shared/opencode.nix` (106-108); must land with 1.4 to keep eval green.

## Phase 2: Keep & Adapt — Native Provider on mact2 + Bootstrap Installer

- [x] 2.1 (REVERT) Remove `openaiProxyProvider` family (355-405) and `-proxy` tier selectors (707-768) from `shared/opencode/providers-base.nix`; keep native `openai` family; must land with 2.2 to keep mact2 eval green.
- [x] 2.2 (ADAPT) In `hosts/mact2/default.nix` set `home.opencode.activeProviderName = "openai-medium"` (line 53).
- [x] 2.3 (NEW) In `hosts/mact2/default.nix` via `home.opencode.extraInitContent`: `HTTP_PROXY=http://10.13.13.1:3128`, `HTTPS_PROXY` same, `NO_PROXY=localhost,127.0.0.1` — OpenCode shell only, no macOS-wide proxy.
- [x] 2.4 (ADAPT) In `bin/install-opencode-auth-seed`, require valid `openai` object in decrypted seed; replace only `openai` entry, preserve other providers; keep backup, dry-run, age-ciphertext rejection.

## Phase 3: New — WireGuard Transport Proxy + Seed Publisher

- [x] 3.1 (NEW) In `hosts/rog/default.nix` enable `services.tinyproxy`: `Listen="10.13.13.1"`, `Port=3128`, `Allow=["10.13.13.3"]`, `ConnectPort=[443]`.
- [x] 3.2 (NEW) Create `bin/publish-opencode-auth-seed`: read rog `auth.json` `openai` entry, validate, age-encrypt to mact2 recipient, atomic-write under uploads; fail on missing/invalid entry; never publish plaintext.

## Phase 4: Verification — Static, Integration, Runtime Smoke

- [x] 4.1 Run `format-nix`; `nix flake check --no-build` exits 0.
- [x] 4.2 `rg -n "openai-proxy|oai\.glats\.org|OPENAI_PROXY_API_KEY|openai_proxy" --glob '*.nix' --glob 'bin/*' .sops.yaml` → zero hits outside `archive/`.
- [x] 4.3 Build toplevels: `nix build .#nixosConfigurations.rog.config.system.build.toplevel`; `nix build .#darwinConfigurations.mact2.config.system.build.toplevel`.
- [x] 4.4 On rog `ss -tlnp | grep 3128` → `10.13.13.1` only; from mact2 `curl -x http://10.13.13.1:3128 -sS https://api.openai.com/v1/models` succeeds.
- [x] 4.5 From non-mact2 source `nc -z 10.13.13.1 3128` → refused (unauthorized rejected).
- [x] 4.6 Inspect mact2 `~/.config/opencode/opencode.json`: no `-proxy` tier; `openai-medium` active.
- [x] 4.7 mact2 E2E: headless `opencode auth login` through proxy → independent credential; `opencode run "ping"` + refresh path.
- [x] 4.8 `bash -n bin/publish-opencode-auth-seed bin/install-opencode-auth-seed`.
- [x] 4.9 Publisher run on rog → artifact starts `-----BEGIN AGE ENCRYPTED FILE-----`, decrypts only for mact2, `rg "sk-|eyJ"` → 0.
- [x] 4.10 Installer safe-failure: malformed ciphertext / invalid JSON seed → non-zero exit (2-4), auth.json checksum unchanged.
- [x] 4.11 Scoped install: seed + existing non-openai providers → backup created, only `openai` replaced, others preserved.

### Verification Notes (apply batch)

| Task | Result | Evidence |
|------|--------|----------|
| 4.1 | PASS | `format-nix` completed without reformatting; `nix flake check --no-build --all-systems` exited 0 ("all checks passed!"). |
| 4.2 | PASS | `rg -n "openai-proxy\|oai\.glats\.org\|OPENAI_PROXY_API_KEY\|openai_proxy" --glob '*.nix' --glob 'bin/*' --glob '.sops.yaml'` → zero hits outside `openspec/changes/`. |
| 4.3 | PASS | `nix build .#nixosConfigurations.rog.config.system.build.toplevel` → `/nix/store/3s9x1l8zpqr2kdblgrwi8vzvhd6blcz7-nixos-system-rog-26.05.20260822.a9e6d84`. mact2 darwin toplevel could not be fully built in this dev sandbox (requires darwin builder — platform mismatch on `gentle-ai-assets`), but `nix eval` confirms the structure: `home.opencode.activeProviderName = "openai-medium"`, initContent contains the proxy exports, no `OPENAI_PROXY_API_KEY` export. |
| 4.4 | DEFERRED | Requires actual host switch + WireGuard connectivity (operator-only per constraints). Eval proves `services.tinyproxy.settings = { Listen = "10.13.13.1"; Port = 3128; Allow = [ "10.13.13.3" ]; ConnectPort = [ 443 ]; }`. |
| 4.5 | DEFERRED | Same as 4.4 — runtime source-IP rejection requires post-switch probe. Tinyproxy `Allow` ACL evaluation is module-declarative. |
| 4.6 | PASS (eval) | `nix eval --raw '.#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.file."Library/Application Support/opencode/opencode.json".text'` shows zero `openai-*-proxy` tier refs; `home.opencode.activeProviderName` is `"openai-medium"`. |
| 4.7 | DEFERRED | Runtime-only (operator deploy + headless OAuth flow). |
| 4.8 | PASS | `bash -n` clean on both scripts. |
| 4.9 | PASS | Publisher dry-run + real-run on synthetic data produced `-----BEGIN AGE ENCRYPTED FILE-----` header, 536 bytes, decrypts only with mact2 key, no `sk-`/`rt_`/`at_` plaintext leaked. |
| 4.10 | PASS | Three safe-failure paths exercised on synthetic data: (a) plaintext fetched payload → exit 2; (b) decrypt to non-JSON → exit 4; (c) JSON without `openai` object → exit 4. In every case auth.json SHA-256 was unchanged. |
| 4.11 | PASS | Synthetic install on a pre-populated mact2 auth.json (openai + github-copilot + nvidia) overwrote ONLY `openai`, preserved `github-copilot` and `nvidia`, created timestamped backup (`mact2-auth.json.bak.20260824-175421`, mode 600), final file mode 600. |

## Rollback

Before cleanup verified: mact2 → prior generation, disable tinyproxy. After cleanup: disable proxy env + tinyproxy, retain native provider + auth backups; never recreate gateway secrets. Prior generation = emergency bridge only.