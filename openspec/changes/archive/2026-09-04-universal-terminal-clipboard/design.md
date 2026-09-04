# Design: Universal Terminal Clipboard

## Technical Approach

Keep the existing tmux OSC 52 write-only core (`shared/tmux.nix`) as the single outbound protocol for every managed flow (local, SSH, nested tmux, OpenCode). Do not add remote clipboard binaries, forwarding, or a daemon. Close the two real gaps: (1) Wetty's unverified/unpinned image, and (2) undeclared receiver policy for Kitty/Alacritty. Document, rather than "fix", the boundaries that OSC 52 cannot cross: MATE Terminal (VTE), kmscon, and XRDP `cliprdr` reconnect state. tmux's own paste buffer is the durable fallback everywhere, independent of any client.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Outbound protocol | OSC 52 write-only via existing `@override_copy_command` | OSC 52 read/query support | Reads let any client claim clipboard control and break the write-only security boundary the spec requires (Non-Goals requirement) |
| Wetty clipboard bridge | Verify current `wettyoss/wetty:latest` xterm.js addon support first; if absent, pin a digest with a known-working OSC52/clipboard addon config | Fork/patch a custom frontend | Pinning is lower-maintenance than forking; a fork is only justified if no maintained image supports the addon (blocked on evidence, see Open Questions) |
| Kitty/Alacritty policy | Declare explicit `clipboard_control`/equivalent config once the pinned nixpkgs version is checked against changelogs/docs | Leave undeclared (status quo) | Spec requires recorded, verified policy, not assumed defaults |
| MATE/kmscon | Document as unsupported/bounded; rely on tmux paste-buffer + reattach | Add `xclip`/local X11 write for MATE session | Remote-host clipboard writes are explicitly out of scope; MATE's local X11 case is a different, non-SSH context the spec does not ask to fix |
| XRDP reconnect | Verify actual `cliprdr` behavior across disconnect/reconnect and document result | Add clipboard-sync logic in `xrdp-session.sh` | tmux buffer already survives disconnect (excluded from cleanup); `cliprdr` itself is an XRDP-owned channel outside our tmux contract, so scope is verification+docs, not new code |
| Image tagging | Move `wetty` container off `:latest` to a pinned tag/digest | Keep `:latest` | `:latest` makes clipboard behavior non-reproducible and unauditable, contradicting the proposal's audit requirement |

## Data Flow

    tmux copy (any pane, any nesting depth)
         │  @override_copy_command → OSC 52 "c" write to /dev/tty
         ▼
    allow-passthrough (per tmux layer) ──▶ SSH PTY (transparent, no binaries)
         │
         ▼
    Receiving terminal
      ├─ Ghostty / (verified Kitty/Alacritty): native OS clipboard  [covered]
      ├─ Wetty: WebSocket → xterm.js → browser Clipboard API        [gap: evidence needed]
      ├─ MATE Terminal (VTE): sequence ignored, no clipboard write  [documented limit]
      └─ kmscon: no graphical receiver                              [documented limit]

    tmux paste buffer (always populated on copy, independent of the above)
         │
         ▼
    reattach from ANY supported client → `paste-buffer` returns last copy
    (works even after XRDP disconnect, kmscon session, or Wetty tab close)

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `linux/system/services/web/wetty.nix` | Modify | Pin `image` to a digest/tag instead of `:latest`; add `cmd`/env flags for the clipboard addon if the verified image requires explicit enablement |
| `linux/home/kitty.nix` | Modify | Add explicit clipboard-write setting once the pinned kitty version's default is confirmed (currently undeclared) |
| `linux/home/alacritty.nix` | Modify | Add explicit `clipboard` policy setting (currently absent) once confirmed |
| `docs/terminal-clipboard.md` | Create | Flow map table (receiver × path × fallback × limit), covering all 9 contexts from the spec |
| `linux/system/desktop/kmscon.nix` | No functional change | Add a comment documenting the no-external-clipboard boundary (docs-only) |
| `linux/system/services/xrdp.nix`, `xrdp-session.sh` | No functional change expected | Verify only; a change is added ONLY if the reconnect test in Testing Strategy fails to preserve tmux buffer (it currently should not, since `tmux` is already in `is_excluded`) |
| `shared/tmux.nix` | No change | Already implements the write-only OSC 52 + passthrough + paste-buffer contract; verified correct during explore |

## Interfaces / Contracts

No new Nix option surface. Existing `virtualisation.oci-containers.containers.wetty.image` (string) changes value only. No new module options are introduced — this keeps the change minimal per the proposal's scope.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Manual/Integration | Local copy: tmux → Ghostty | Copy text via tmux-yank, inspect OS clipboard |
| Manual/Integration | SSH + nested tmux passthrough | Copy from doubly-nested tmux (local→SSH→remote), confirm outer clipboard, confirm no `xclip`/`wl-copy`/`pbcopy` process spawned remotely (`ps` check) |
| Manual/Integration | Reattach recovery | Copy, kill client (SSH drop / XRDP disconnect / kmscon), reattach from a different client, run `tmux paste-buffer` |
| Manual/Integration | Wetty bridge | Copy inside Wetty tmux session over HTTPS, verify browser clipboard; test oversized payload rejection; test non-HTTPS/no-gesture path is blocked |
| Manual/Integration | XRDP `cliprdr` reconnect | Disconnect/reconnect RDP client, record whether `cliprdr` clipboard state persists (documentation outcome, not a pass/fail gate on our code) |
| Manual | MATE Terminal negative test | Confirm VTE ignores OSC 52 (no clipboard change, no fallback triggered) |
| Manual | Kitty/Alacritty verification | Copy test per pinned version against documented config |
| Build | `nix flake check --no-build` | Standard gate for all touched hosts (rog for wetty, all Linux hosts for kitty/alacritty) after any `.nix` edit |

No automated unit tests are introduced: this change is glue configuration (container image pin, terminal settings, docs) with no new parsing/handler code in this repo unless the Wetty gap forces a custom frontend (see Open Questions) — that scenario would need its own test plan for the OSC 52 payload parser (size-bound rejection, UTF-8 decode, secure-context gate).

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary is introduced. The Wetty container change modifies an image reference and CLI args, not a shell/subprocess execution path this repo owns.

## Migration / Rollout

Pin the Wetty image first (low-risk, revertible via `image` string rollback) and validate on `rog` alone (its only host) before declaring Wetty covered. Kitty/Alacritty policy declarations are additive config and roll out with the normal Linux host build/switch cycle. No data migration; no phased flag needed — each file change is independently revertible per the proposal's Rollback Plan.

## Open Questions

- [ ] **BLOCKING for Wetty task**: Does `wettyoss/wetty:latest` (or a specific pinned tag) actually implement an OSC 52 write handler + Clipboard API call? No evidence found in this repo or via prior GitHub search (butlerx/wetty upstream showed no `ClipboardAddon`). Must inspect the deployed image's source/CHANGELOG or run a live test on `rog` before writing the final Wetty task. If unsupported, decide: wait for upstream support, or accept a custom frontend fork (higher effort, was explicitly deprioritized in explore).
- [ ] **Needs verification, non-blocking**: Exact Kitty/Alacritty clipboard-write default behavior for the pinned nixpkgs versions — check `programs.kitty`/`programs.alacritty` option docs and changelogs, not assumption.
- [ ] **Needs verification, non-blocking**: Actual XRDP `cliprdr` behavior across disconnect/reconnect — requires a live test on `rog`; outcome is documentation-only, does not block other file changes.

## Key Learnings

1. The Wetty container currently pins no image tag/digest (`:latest`), which is the single actionable code risk in this change; everything else is docs/config.
2. `xrdp-session.sh` already excludes `tmux` from its PID-cleanup phases, so tmux buffer survival across XRDP disconnect requires no code change — only a verification test.
3. Neither Kitty nor Alacritty declares an explicit clipboard policy in this repo today, so their OSC 52 support is currently assumed, not verified, per the spec's requirement.
4. No automated test infrastructure exists for this change's scope; verification is manual/integration only unless the Wetty gap forces a custom OSC 52 parser.
