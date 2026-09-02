# Terminal Clipboard Routing

## Purpose

This document maps how a copy action performed inside tmux (or OpenCode, which
runs inside tmux) reaches a client-side clipboard across every managed
terminal/transport combination in this repo. It defines the single outbound
protocol, the durable local fallback, and the exact boundary of each receiver
so no flow silently assumes support it cannot verify.

Related: `openspec/changes/universal-terminal-clipboard/{proposal.md,design.md,specs/terminal-clipboard-routing/spec.md}`.

## Core Contract (all flows)

- **Outbound protocol**: OSC 52 write (`c`) mode only, emitted by tmux's
  `@override_copy_command` (`shared/tmux.nix`). No OSC 52 reads/queries are
  emitted or honored anywhere in this contract.
- **Durable fallback**: tmux's own paste buffer (`tmux paste-buffer`, bound to
  `p` in `shared/tmux.nix`) always holds the last copy, independent of any
  client connection. This is the recovery path when a receiver does not
  support OSC 52 or a client disconnects.
- **No remote clipboard tools**: `xclip`, `wl-copy`, `pbcopy`, X11/Wayland
  socket/display forwarding, and any clipboard-synchronization daemon are
  explicitly out of scope and MUST NOT be invoked from a tmux session reached
  over SSH.
- **Passthrough requirement**: every tmux layer in a nested session (local →
  SSH → remote tmux) must have `allow-passthrough on` for the OSC 52 sequence
  to reach the outermost client. `shared/tmux.nix` sets this once; it applies
  to every layer because the same tmux config is used on every host.

## Flow Matrix

| Flow | Primary path | Fallback | Status | Limit / Boundary |
|------|--------------|----------|--------|-------------------|
| Local tmux copy | tmux `@override_copy_command` → OSC 52 write to `/dev/tty` of the attached client | `tmux paste-buffer` | Supported | Requires an OSC 52-aware receiver terminal (see per-terminal rows below) |
| Nested tmux (local tmux → SSH → remote tmux) | OSC 52 traverses each `allow-passthrough on` layer unmodified | `tmux paste-buffer` at any layer | Supported | Breaks if any nesting level lacks `allow-passthrough on`; this is a documented unsupported configuration, not a silent degrade to a remote tool |
| SSH (single hop) | OSC 52 sequence rides the interactive PTY unmodified to the local client | `tmux paste-buffer` on the remote host | Supported | Remote host clipboard state (X11/Wayland/macOS pasteboard) is never touched; no `xclip`/`wl-copy`/`pbcopy` process is spawned remotely |
| OpenCode (inside tmux, local or over SSH) | Inherits the tmux/SSH/passthrough contract above — OpenCode emits OSC 52 like any other program | `tmux paste-buffer` | Supported | OpenCode's own native fallback (`wl-copy`/`xclip`/`osascript`) is not relied upon for the remote case; only the tmux OSC 52 path is used |
| Ghostty (managed graphical receiver) | Native OS clipboard via OSC 52 write | N/A (native support) | **Verified**: `clipboard-write = "allow"` explicitly set in `shared/ghostty.nix` | Read/paste-protection intentionally left disabled/off — write-only by design |
| Kitty (managed graphical receiver) | Native OS clipboard via OSC 52 write | N/A (native support) | **Verified**: pinned nixpkgs kitty 0.48.2 ships `clipboard_control` default `('write-clipboard', 'write-primary', 'read-clipboard-ask', 'read-primary-ask')` — write is enabled out of the box; this repo declares no override, so the upstream default applies | Read is not fully disabled by default — it is gated behind an interactive per-request permission prompt (`-ask`), which is a stricter posture than plain "read enabled" but is not identical to "never responds to reads". No config change applied in this change; documented as-is |
| Alacritty (managed graphical receiver) | Native OS clipboard via OSC 52 write | N/A (native support) | **Verified**: pinned nixpkgs alacritty 0.17.0 defaults `terminal.osc52 = "OnlyCopy"` (write-only; read/paste is rejected by default) — matches the write-only contract with zero configuration needed | This repo declares no explicit `osc52` override; verified default is already correct |
| MATE Terminal (VTE-based, XRDP desktop) | None — VTE does not implement OSC 52 | `tmux paste-buffer` (recoverable only by reattaching from a supported client) | **Documented unsupported** | Copying inside MATE Terminal never updates the OS clipboard via OSC 52; no remote clipboard tool is used as compensation |
| Wetty (browser terminal over HTTPS) | Intended: WebSocket → xterm.js → browser Clipboard API | `tmux paste-buffer` (reattach via SSH/Ghostty from the same tmux session) | **Blocked — unsupported, evidence-based** (see Wetty Evidence Spike below) | No frontend fork, custom OSC 52 parser, or image pin is applied in this change. Wetty must not be represented as clipboard-capable until upstream ships `@xterm/addon-clipboard` (or an equivalent OSC 52 handler) and that release is verified on the deployed image |
| kmscon (bare console, no X11/Wayland) | None — no graphical/OSC 52 receiver exists | `tmux paste-buffer`, recovered by reattaching the same tmux session from a supported client (e.g. SSH + Ghostty) | **Documented bounded limit** | The system never claims a kmscon session reached an external clipboard; only reattach-and-recover is guaranteed |
| XRDP/`cliprdr` reconnect | `cliprdr` RDP channel (owned by XRDP, outside the tmux/OSC 52 contract) | `tmux paste-buffer`, guaranteed independent of `cliprdr` state | **tmux survival verified by code inspection; `cliprdr` continuity not live-tested in this change** (see XRDP section below) | tmux session survival across XRDP disconnect does not depend on `cliprdr`; `cliprdr` clipboard continuity across reconnect is NOT guaranteed by this contract |

## Wetty Evidence Spike (Phase 1, Task 1.1–1.2)

**Question**: Does the currently deployed `wettyoss/wetty:latest` image implement
an OSC 52 write handler that calls the browser Clipboard API?

**Evidence gathered** (GitHub code search + npm/pnpm-lock inspection of
`butlerx/wetty`, upstream of the `wettyoss/wetty` Docker image):

- The project's `pnpm-lock.yaml` / published `package.json` dependency list
  includes only `@xterm/addon-fit`, `@xterm/addon-image`,
  `@xterm/addon-web-links`, `@xterm/addon-webgl`, and `@xterm/xterm`.
  **`@xterm/addon-clipboard` is not a dependency.**
- xterm.js core does **not** implement OSC 52 by default (confirmed via
  xterm.js issue #3260 and PR #4220/#4863 — OSC 52 support was deliberately
  moved out of core and into the optional `@xterm/addon-clipboard` package,
  which embedders must explicitly install and load).
- No `ClipboardAddon`, custom OSC 52 `registerOscHandler`, or equivalent
  clipboard bridge code exists anywhere in the `butlerx/wetty` source tree
  (confirmed via repository search; only `docs/` mentions of "clipboard"
  concern the internal editor config, not xterm.js OSC 52).
- Comparable projects (`ttyd`, `sshwifty`, `coder`) that DO support OSC 52 in
  a browser terminal all had to explicitly add `@xterm/addon-clipboard` or a
  hand-written `registerOscHandler(52, ...)` call — none of this exists in
  `wetty`.

**Conclusion**: `wettyoss/wetty:latest` does **not** implement an OSC 52 write
handler or a Clipboard API bridge as of this evidence-gathering pass. Per
Phase 1, Task 1.2, this is a **documented unsupported/blocked** decision:

- No frontend fork or custom OSC 52 parser is introduced by this change
  (would require a new parsing/handler code path with its own threat model —
  explicitly out of scope per design.md, which flags this as "higher effort,
  explicitly deprioritized").
- No image pin or version bump is applied on the strength of an assumed or
  invented clipboard capability. `linux/system/services/web/wetty.nix` is
  left unmodified in this change.
- Wetty remains a **view-only terminal for clipboard purposes**: reattach
  from a supported client (SSH + Ghostty/Kitty/Alacritty) to retrieve any
  text copied during a Wetty session, using `tmux paste-buffer`.

**Recovery path if Wetty support becomes desired later**: re-run this
evidence check against whatever `wettyoss/wetty` tag is current at that time
(check its `package.json`/lockfile for `@xterm/addon-clipboard`, or a custom
`registerOscHandler(52, ...)` call in the shipped bundle). Only pin/adopt a
specific tag once that evidence exists — do not assume a newer `:latest` has
gained the feature.

## XRDP / MATE `cliprdr` Reconnect

- **tmux buffer survival (verified by code inspection)**:
  `linux/system/services/xrdp-session.sh`'s `is_excluded()` function already
  excludes `tmux` from its PID-cleanup phases (`ssh-agent|gpg-agent|gnome-keyring-d|gnome-keyring-daemon|.gnome-keyring-*|tmux`
  matched literally, and `*gnome-keyring*|*tmux*` matched as a substring
  fallback). This means an XRDP disconnect does not kill the user's tmux
  session or its paste buffer — no code change was required or made.
- **`cliprdr` channel continuity (not live-tested in this change)**: the RDP
  `cliprdr` clipboard-sync channel is owned entirely by XRDP/FreeRDP, outside
  this repo's tmux/OSC 52 contract. Whether `cliprdr` automatically resumes
  clipboard sync after a reconnect, or requires a fresh copy action, was
  **not verified against a live `rog` session in this change** (no live RDP
  session was available in this execution context). This is recorded as an
  **open verification item**, consistent with design.md's own "non-blocking"
  classification of this question — it does not block or change any file in
  this change, since tmux buffer survival (the guarantee this repo owns) is
  already correct.
- **Guarantee actually made**: regardless of `cliprdr` behavior, `tmux
  paste-buffer` always retrieves the last copy after any XRDP
  disconnect/reconnect, because the tmux session itself was never killed.

## kmscon Bounded Console Limit

kmscon provides a bare Linux console with no X11/Wayland session and no
graphical or OSC 52-capable receiver. Running tmux inside kmscon and copying
text via tmux-yank:

- Never reaches an external/graphical clipboard — this is never claimed.
- Always populates the tmux paste buffer, exactly as any other tmux session.

**Recovery**: reattach the same tmux session from a supported client (for
example, SSH into the same host and open it from Ghostty, Kitty, or
Alacritty) and run `tmux paste-buffer` (bound to `p`) to retrieve the text,
which that client's OSC 52-capable terminal can then forward to its own OS
clipboard.

## Cross-Platform Parity (Linux / macOS)

`shared/tmux.nix` is imported by both Linux hosts and `mact2` (Darwin), and
contains the entire `allow-passthrough`/`set-clipboard`/
`@override_copy_command` contract in one place. Both platforms get an
identical OSC 52 write configuration; only escape-time and plugin-loading
mechanics differ per platform (documented in the file's header comment), not
the clipboard contract itself.

## Manual Verification Plan (Phase 3)

These are manual/integration test cases — no automated test infrastructure
exists for this change's scope (glue configuration + docs only; no new
parsing/handler code was introduced).

### 3.1 Local / SSH / nested tmux / OpenCode

1. **Local tmux → Ghostty**: open a local tmux session in Ghostty, select
   text with tmux-yank (`prefix v` to start selection, `y`/copy-mode exit to
   yank). Inspect the OS clipboard (paste anywhere outside the terminal) —
   MUST contain the copied text.
2. **SSH passthrough**: SSH from a Ghostty/Kitty/Alacritty client into a
   remote host, start tmux remotely, copy text. Confirm the local client's
   OS clipboard receives the text. Run `ps aux | grep -E 'xclip|wl-copy|pbcopy'`
   on the **remote** host during and after the copy — MUST show no such
   process.
3. **Nested tmux**: local tmux (passthrough on) → SSH → remote tmux
   (passthrough on) → copy from the innermost pane. Confirm the outermost
   client's clipboard receives the text.
4. **Negative nested case**: disable `allow-passthrough` on one nesting
   level, repeat the copy, and confirm the OSC 52 sequence does NOT reach
   the outer clipboard (documents the unsupported-configuration boundary;
   do not "fix" this with a remote clipboard tool).
5. **OpenCode**: run OpenCode inside a tmux session reached over SSH, use
   OpenCode's copy action, and confirm the sequence follows the same path
   as step 2 (no separate/native OpenCode clipboard mechanism is invoked
   for the remote case).

### 3.2 Wetty (manual — expected to fail with current image, per evidence spike)

1. Access Wetty over HTTPS, open a tmux session, copy text via tmux-yank.
   **Expected current result**: browser clipboard is NOT updated (no OSC 52
   handler present in the deployed image — see Evidence Spike above). This
   is the expected, documented outcome, not a regression.
2. If/when a future Wetty release adds `@xterm/addon-clipboard` (or
   equivalent) and is verified per the recovery path above, re-run this test
   expecting: HTTPS/secure-context write succeeds after focus/gesture;
   oversized payload is rejected/truncated per the addon's documented size
   bound; non-HTTPS or no-gesture context blocks the write with no remote
   clipboard tool fallback on the Wetty host.

### 3.3 XRDP disconnect/reconnect

1. Start a tmux session inside an XRDP/MATE desktop, copy text.
2. Disconnect the RDP client (network drop or session lock).
3. Confirm (via a separate SSH session, or after reconnecting) that the
   tmux session is still running and `tmux paste-buffer` returns the copied
   text.
4. Reconnect the RDP client and attempt a `cliprdr` copy/paste. Record
   whether clipboard sync resumes automatically or requires a fresh copy —
   this is a documentation outcome (see XRDP section above), not a pass/fail
   gate on this repo's code.

### 3.4 Negative tests: MATE/VTE and kmscon

1. Run tmux inside MATE Terminal, copy via tmux-yank. Confirm the OS
   clipboard is NOT updated via OSC 52, and confirm no remote clipboard tool
   process is spawned as a fallback.
2. Run tmux inside kmscon, copy via tmux-yank. Confirm no external/graphical
   clipboard is claimed or touched, and confirm `tmux paste-buffer` still
   holds the text. Reattach from a supported client and confirm recovery.

## Nix Verification Gate (Phase 4.1)

Any future `.nix` edit touching a file in this flow map (`shared/tmux.nix`,
`linux/home/{kitty,alacritty}.nix`, `shared/ghostty.nix`,
`linux/system/services/web/wetty.nix`, `linux/system/services/xrdp*.nix`,
`linux/system/desktop/kmscon.nix`) MUST be followed by:

```sh
format-nix && nix flake check --no-build
```

`nix flake check` (without `--no-build`) evaluates AND builds every NixOS
host's toplevel via `flake.nix`'s `checks.x86_64-linux` — always use
`--no-build` while iterating; only run a full build/switch on the
specific host being changed (see Host Notes below).

### Host Notes (Phase 4.2)

No `.nix` file was modified by this change (the Wetty gap stayed
docs-only per the evidence spike; Kitty/Alacritty defaults were verified as
already correct with no override needed). If a future change modifies:

- `linux/system/services/web/wetty.nix` — only affects `rog` (its sole
  deployed host). Rebuild/switch `rog` after `nix flake check --no-build`
  passes.
- `linux/home/kitty.nix` / `linux/home/alacritty.nix` — affects every Linux
  host importing `linux/home/shared-modules.nix` (`rog`, `thinkcentre`,
  `t14`) plus any host-specific extras. Rebuild/switch each touched host.
- `shared/tmux.nix` — affects every Linux host AND `mact2` (Darwin). Rebuild
  Linux hosts with `nixos-build`; rebuild `mact2` with `darwin-rebuild`
  (or its documented build path) separately.

## Completion Gate (Phase 4.3)

This change is complete when:

- [x] The Wetty evidence spike is recorded with concrete evidence (package
      manifest / xterm.js addon architecture), not assumption.
- [x] The docs matrix above assigns every one of the 9 required flows
      (tmux, nested tmux, SSH, OpenCode, Ghostty, Kitty, Alacritty,
      MATE/XRDP, Wetty, kmscon) a primary path, fallback, status, and limit.
- [x] The manual verification plan covers local/SSH/nested/OpenCode copy,
      Wetty (expected-fail today), XRDP reconnect, and MATE/kmscon negative
      cases.
- [ ] Live manual execution of the Phase 3 test plan on real hardware
      (`rog` for XRDP/Wetty, any host for local/SSH/nested cases) — not
      performed in this change; this repo change only prepares and records
      the verification plan and the code-level evidence available without
      live hardware access.
