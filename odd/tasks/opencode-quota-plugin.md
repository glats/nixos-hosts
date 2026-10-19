# opencode-quota-plugin

Objective: show OpenAI, Anthropic and OpenCode Go plan usage inside OpenCode through `@slkiser/opencode-quota`, which requires bumping the managed OpenCode runtime.
Branch: `feature/monitoring-llm`. Delivery strategy: `single-pr` (push/PR left to the user). Test runner: `nix build`, `python3 shared/opencode/*.test.py`, `go -C pkgs/nixos-scripts test ./...`, host `nix eval`, `nix flake check --no-build`.

## Specs

S1. "no habra un plugin para opecnode que mmuestre el usage de mis planes: oepnai, anthropic y opecnode go?" — OpenCode loads `@slkiser/opencode-quota` pinned at `5.0.3` (no `@latest`), so `/quota` reports OpenAI, Anthropic and OpenCode Go quota on every host that receives the shared OpenCode config.
S2. User decision "2.0.32 (latest)": `pkgs/opencode` moves from `2.0.14` to `2.0.32` for all four platforms with observed hashes. This is the explicit runtime-upgrade decision required by `docs/gentle-ai-update.md`; docs that state the runtime version are updated.
S3. User decision "Panel lateral (Recomendado)": a Nix-managed `~/.config/opencode/opencode-quota/quota-toast.jsonc` sets `enabledProviders: "auto"`, `tuiSidebarPanel.enabled: true`, `enableToast: false`, `tuiCompactStatus.enabled: false`.
S4. Existing behavior holds: `opencode-claude-subscription@0.1.4`, herdr, gentle-ai assets/review transport, Engram, RTK, providers, agents and MCPs keep working; gentle-ai assets still render with the bumped binary.
S5. Assumption: OpenAI quota needs a Codex OAuth login (`/connect` → OpenAI → Codex legacy); Anthropic uses OpenCode's own `anthropic` login. Login changes are the user's, not part of this change.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S2, S4 | parent inline (no writer trigger) | done | commit 6346eb14; L5 |
| T2 | S1, S3, S4 | parent inline (no writer trigger) | done | commit 532f2cc1; L6 |
| T3 | S1-S5 | delegated gentle-ai-verify (Risk items 3, 5) | done | L8 |

## Log

L1 (2026-10-17, user, verbatim): "no habra un plugin para opecnode que mmuestre el usage de mis planes: oepnai, anthropic y opecnode go?"
L2 (2026-10-17, user, verbatim): "suena bien. vamos con full odd"
L3 (2026-10-17, research): `@slkiser/opencode-quota` latest `5.0.3`, MIT, ~1k stars; peerDependency `@opencode/plugin 2.0.16`, requires OpenCode ≥ 2.0.16 and Node ≥ 22.13 (only for the npx CLI). One `plugin` entry loads server and TUI; settings live in `opencode-quota/quota-toast.jsonc` next to the OpenCode config. Managed runtime is `pkgs/opencode` 2.0.14; npm latest is 2.0.32. `docs/gentle-ai-update.md` pins 2.0.14 and requires an explicit runtime-upgrade decision; `pkgs/gentle-ai-assets/render.nix` renders with the native binary.
L4 (2026-10-17, user decisions): bump target "2.0.32 (latest)"; TUI display "Panel lateral (Recomendado)".
L5 (2026-10-17, T1 checks): 2.0.32 hashes prefetched for linux-x64/arm64, darwin-x64/arm64; `nix build .#opencode .#gentle-ai-assets` OK, `opencode v2.0.32`; rendered gentle-ai-assets byte-identical vs 2.0.14 (`diff -rq` empty). v2-agents and asset-ownership tests PASS; go tests PASS; rog/thinkcentre/t14 toplevel eval OK; `nix flake check --no-build` all checks passed (one earlier transient "path ... is not valid" did not reproduce). `docs/gentle-ai-update.md` runtime row updated; `opencode-login-bridge` help text left at 2.0.14 because its ports were not re-verified on 2.0.32.
L6 (2026-10-17, T2 checks): RED — home-launcher test failed on missing `.config/opencode/opencode-quota/quota-toast.jsonc`. GREEN — plugin and config assertions pass. Baseline home-launcher already failed (fromJSON of opencode.json with supermercados store-path context); fixed with `unsafeDiscardStringContext`. Remaining pre-existing failure: stale profile assertion `openai-anthropic-medium` (profiles renamed in 8796da27), out of scope. Isolated 2.0.32 runtime probe (temp XDG dirs, own service port): `debug config` accepts `plugins`; log `loading plugin id=@slkiser/opencode-quota@5.0.3`; `plugin list` shows `@slkiser/opencode-quota.server 5.0.3` alongside `opencode-claude-subscription 0.1.4`.
L7 (2026-10-17, user, verbatim): "bro pero hiciste topdo inline" — accepted: exploration exceeded the mapping budget and long builds/probes should have been delegated; T3 goes to an independent verifier.
L8 (2026-10-17, verify): independent verifier PASS S1-S5, no blockers. Feature baseline is 0e8ebf7e (HEAD~2), not 834e6068. Hashes re-prefetched and equal; build OK `opencode v2.0.32`; rendered rog opencode.json differs from baseline only in `plugins`; quota-toast.jsonc rendered exactly per S3; v2-agents/asset-ownership/go tests PASS; Linux NixOS and standalone HM evals OK; flake check passed; macm5 darwin eval fails at baseline too (gentle-ai-assets IFD). Isolated probe lists `@slkiser/opencode-quota.server 5.0.3` after npm install (>20s). Advisories: darwin hashes not built natively; stale `openai-anthropic-medium` profile assertion pre-existing. Pending (user): activation on hosts, `/quota` observed live, OpenAI Codex-legacy login if ChatGPT quota shows unavailable, push/PR.
L9 (2026-10-19, user report): on 2.0.32 the OpenAI login switched to `https://auth.openai.com/api/accounts/authorize` (client_id=dynamic_agent_client) with a RANDOM 127.0.0.1 callback port per attempt (observed 35929, path /auth/callback), so the L5 pending help-text/ports item is resolved differently than fixed ports: `opencode-login-bridge` gained repeatable `-url <authorizeURL>` that extracts the `redirect_uri` callback port (defaults unchanged for legacy OpenAI 1455/1457 and Claude 53692); tests in cmd/opencode-login-bridge/main_test.go, go suite PASS.
L10 (2026-10-19, user question + decision): asked whether the flag should be per-provider (`-url-openai`). Decision: keep `-url` provider-generic (any authorize URL with redirect_uri parses identically — Claude verified in tests, future flows need no new flag, repeatable per login) and differentiate at runtime output instead: ports carry their authorize host and `bridge up` renders `:35929 (auth.openai.com)`; the post-up instruction adapts per mode (login-first when `-url` was used, bridge-first otherwise). `--url` spelling works too (Go flag). Suite/gofmt/vet/build PASS.
L11 (2026-10-19, user, verbatim): "probe y thinkcentre hizo login con openai" — OpenAI login confirmed completed on thinkcentre; closes the L8 pending item "OpenAI Codex-legacy login if ChatGPT quota shows unavailable". Remaining L8 pendings: `/quota` observed live in the TUI.
