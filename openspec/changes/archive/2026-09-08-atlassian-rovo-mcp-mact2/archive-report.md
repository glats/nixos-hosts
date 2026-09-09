# Archive Report: atlassian-rovo-mcp-mact2

**Change:** atlassian-rovo-mcp-mact2
**Archived:** 2026-09-08
**Archive path:** `openspec/changes/archive/2026-09-08-atlassian-rovo-mcp-mact2/`
**Status:** Completed, user-confirmed on mact2 ("quedó bien", 2026-09-08)
**Mode:** openspec (filesystem archive; no Engram persistence for this repo)

## Review Verdict

**APPROVED** — all verification gates PASS on current HEAD (7921b80):

| Gate | Command | Result |
|------|---------|--------|
| G1 — Format | `format-nix --check` | PASS (exit 0, no files reformatted) |
| G2 — Flake check | `nix flake check --no-build` | PASS (all checks passed; x86_64-darwin omitted as expected on Linux host) |
| G3 — Eval shape | `nix eval --json .#homeConfigurations.mact2.config.home.ai-assets.extraMcps.atlassian` | PASS → `{"enabled":true,"type":"remote","url":"https://mcp.atlassian.com/v2/mcp"}` |

Selector note (G3): darwin extras live in `home.ai-assets.extraMcps`, merged with base `mcps`
by `shared/opencode/runtime-config.nix`; the base `home.ai-assets.mcps.atlassian` path does not
apply to the mact2 darwin inventory. This correction was captured in tasks 3.3 and is the
verified selectors used at archive time.

## Task Completion

- Phases 1–3 (implementation, documentation, validation): complete at apply time.
- Phase 4 manual gates closed by user confirmation: tasks 4.1 (mact2 rebuild), 4.2 (first
  OAuth 2.1 login confirmed via `opencode mcp list`), 4.3 (sooperset uninstall steps) checked
  off with annotation `user-confirmed deployment on mact2, 2026-09-08 ("quedó bien")`.
- Task 4.4 (optional, human-only legacy-secret confirmation) left unchecked — annotated
  `optional, not confirmed`. Not a blocker: secrets retained inert by design.

## Summary

The official Atlassian Rovo MCP remote (`https://mcp.atlassian.com/v2/mcp`, OAuth 2.1, site
access follows the authorized Falabella account) replaces the mislabeled sooperset
`mcp-atlassian` stdio stack on mact2:

- `darwin/home/opencode/mcps-extra.nix`: `atlassian` entry is now `type = "remote"` (only
  `type`/`url`/`enabled` keys).
- `darwin/home/atlassian-mcp-wrapper.nix` deleted; import removed from
  `darwin/home/shared-modules.nix`.
- `darwin/home/sops.nix`: five atlassian/confluence secret declarations dropped;
  `secrets/user/atlassian.yaml` and `.sops.yaml` retained byte-identical as inert ciphertext
  (retention contract).
- Runbook: `docs/atlassian-rovo-mcp.md` (OAuth login, verify, uninstall, troubleshooting).
- Deployed to mact2 in commit `7921b80` (feat(mact2): migrate atlassian MCP to official Rovo
  remote server); user-confirmed working on 2026-09-08.

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| atlassian-rovo-mcp | Created (NEW) | Delta spec copied from `specs/atlassian-rovo-mcp/spec.md` to `openspec/specs/atlassian-rovo-mcp/spec.md`. Framing normalized to registry convention: title → `# atlassian-rovo-mcp Specification`, scenario tags `[mact2]` → `[hosts: mact2]`, change-specific `## Source Context` section dropped (registry specs carry no Source Context; the change-dir pointer lives in the archived copy). 6 requirements, 8 scenarios preserved verbatim. |

## Mechanical Copy Verification

- Change folder moved with `git mv` to the archive destination; MANDATORY `diff -r` readback of
  the pre-move recursive snapshot vs. the archived destination returned an **empty diff (PASS)**
  — byte identity preserved. `archive-report.md` is additive-only and was not in the source
  snapshot.
- Spec sync: byte-identity copy of the delta verified before the two deliberate framing edits
  (title + Source Context drop); final file diffed against the delta re-transformed with the
  same edits — **empty diff (PASS)**.

## Validation

- `format-nix --check`: exit 0, no reformatting required on HEAD.
- `nix flake check --no-build`: all checks passed; x86_64-darwin checks omitted by the Linux
  host (expected — mact2 rebuild is a manual post-deployment gate, confirmed by user).
- Eval proof matches the spec exactly.

## Outstanding

- None mandatory. Task 4.4 (human-only legacy-secret content confirmation) remains optional and
  is left to the user; it does not affect the deployed state.