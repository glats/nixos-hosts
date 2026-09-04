# Proposal: Universal Terminal Clipboard

## Intent

Make terminal copy behavior predictable across managed clients without copying clipboard data into a remote host or promising support that a console cannot provide. Preserve tmux content through reconnects and make its client-facing path explicit.

## Scope

### In Scope

- Publish one flow map for tmux, nested tmux, SSH, OpenCode, Ghostty, Kitty, Alacritty, MATE/XRDP, Wetty, and kmscon.
- Retain OSC 52 write-only as the primary client-clipboard channel, with tmux `paste-buffer` as the always-local fallback.
- Verify and close the Wetty browser route, including HTTPS/Clipboard API permission, focus, payload limits, and a pinned/auditable image or frontend if required.
- Define XRDP/MATE `cliprdr` behavior across disconnect/reconnect while preserving tmux sessions.
- Document the kmscon limit: no promised external clipboard; reattach the tmux session from a supported client to retrieve its buffer.
- Verify copy paths, nested tmux, OpenCode, bracketed paste, reattach, and XRDP/Wetty reconnection behavior.

### Out of Scope

- OSC 52 reads or programmatic paste from a client clipboard.
- Remote `xclip`, `wl-copy`, `pbcopy`, display/socket forwarding, or a clipboard-sync daemon.
- A claim that unmanaged SSH endpoints, MATE/VTE, or kmscon provide OSC 52 support.

## Capabilities

### New Capabilities

- `terminal-clipboard-routing`: Defines managed terminal copy routing, receiver contracts, fallback behavior, security boundaries, and reconnection guarantees.

### Modified Capabilities

None.

## Approach

Use the existing tmux OSC 52/passthrough configuration as the single outbound protocol. Treat the tmux buffer as independent durable session state. Configure or document receivers only after validating their actual version and policy; Wetty must accept write-only OSC 52, decode bounded text, and call the browser Clipboard API only in a secure, consented client context. SSH remains transparent.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/tmux.nix` | Modified/verified | Primary OSC 52 and tmux-buffer contract. |
| `shared/ghostty.nix`, `linux/home/{kitty,alacritty}.nix` | Verified | Managed graphical receiver policies. |
| `linux/system/services/web/wetty.nix` | Modified | Auditable Wetty clipboard route and image policy. |
| `linux/system/services/web/nginx.nix` | Verified | HTTPS/WebSocket prerequisite. |
| `linux/system/services/xrdp*.nix`, `linux/system/base/profiles/mate.nix` | Verified/documented | `cliprdr` reconnect behavior. |
| `linux/system/desktop/kmscon.nix`, `docs/terminal-clipboard.md` | Modified | Explicit console boundary and flow map. |

Host scope: shared Home Manager paths affect Linux hosts and `mact2`; Wetty and XRDP apply to `rog`/configured XRDP hosts; kmscon applies to Linux consoles.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Visible terminal output overwrites clipboard | Medium | Write-only handling, bounded Wetty payloads, user consent, no reads. |
| Browser clipboard support varies | Medium | Pin/inspect implementation and document focus/permission fallback. |
| Reconnect loses XRDP clipboard state | Medium | Keep tmux buffer authoritative and test reattach. |

## Rollback Plan

Revert receiver-specific changes and restore the prior Wetty image/configuration. Existing tmux buffers and OSC 52 settings remain usable; no persistent daemon or remote clipboard state requires cleanup.

## Dependencies

- Wetty/xterm.js implementation evidence and browser Clipboard API behavior under the deployed HTTPS origin.

## Success Criteria

- [ ] The documented map assigns every managed flow an owner, primary path, fallback, and stated limit.
- [ ] Copy through local/SSH/nested tmux/OpenCode reaches supported clients via write-only OSC 52; `paste-buffer` survives reattach.
- [ ] Wetty and XRDP reconnect tests establish their supported behavior without remote clipboard tools or a synchronization daemon.
- [ ] kmscon is documented as a bounded console path, not an external clipboard guarantee.
