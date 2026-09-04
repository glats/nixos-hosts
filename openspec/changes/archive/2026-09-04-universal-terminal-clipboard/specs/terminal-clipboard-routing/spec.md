# Terminal Clipboard Routing Specification

## Purpose

Define predictable, write-only clipboard routing for copy actions issued inside tmux, SSH, OpenCode, and managed graphical/web/console clients, without introducing remote-clipboard tools, OSC 52 reads, or a synchronization daemon. tmux's own paste buffer is the durable fallback across reconnects.

## Requirements

### Requirement: OSC 52 Write-Only Channel

The system MUST route copy actions from tmux and OpenCode to the client-side clipboard using OSC 52 escape sequences only in write (`c`) mode. The system MUST NOT respond to or emit OSC 52 read/query requests.

#### Scenario: Local copy inside tmux reaches client clipboard

- GIVEN a user is inside a tmux session on a client with OSC 52 write support (e.g. Ghostty)
- WHEN the user copies text via tmux-yank or a program that emits OSC 52
- THEN the client terminal's clipboard MUST contain the copied text
- AND no OSC 52 read/query MUST be sent or honored

#### Scenario: OSC 52 read requests are ignored

- GIVEN any client sends an OSC 52 query (read) sequence to the terminal
- WHEN tmux or the receiving terminal processes the input stream
- THEN the system MUST NOT return clipboard contents in response

### Requirement: tmux Buffer as Durable Fallback

The system MUST retain the most recent copied text in the tmux paste buffer independent of client connectivity, and MUST make it retrievable via `paste-buffer` after any client disconnect/reattach.

#### Scenario: Reattach recovers last copy

- GIVEN a user copied text inside tmux and then the client disconnected (SSH drop, XRDP disconnect, or terminal closed)
- WHEN the user reattaches to the same tmux session from any supported client
- THEN `tmux paste-buffer` MUST return the previously copied text
- AND no external clipboard tool or daemon MUST be required to recover it

### Requirement: SSH Transparency for OSC 52

The system MUST transport OSC 52 sequences unmodified across an interactive SSH session's PTY, and MUST NOT invoke remote clipboard binaries (`xclip`, `wl-copy`, `pbcopy`) or X11/Wayland socket forwarding as part of this path.

#### Scenario: Copy over SSH reaches the local client, not the remote host

- GIVEN a user is connected via SSH from a client terminal into a remote host running tmux
- WHEN the user copies text inside the remote tmux session
- THEN the OSC 52 sequence MUST reach the local client terminal's clipboard
- AND the remote host's clipboard state (X11/Wayland/macOS pasteboard) MUST NOT be modified
- AND no `xclip`, `wl-copy`, or `pbcopy` process MUST run on the remote host as part of this copy

### Requirement: Nested tmux Passthrough

The system MUST forward OSC 52 sequences through nested tmux sessions (tmux running inside tmux, e.g. local tmux → SSH → remote tmux) by enabling passthrough at every nesting level.

#### Scenario: Copy from doubly-nested tmux reaches outer client

- GIVEN a local tmux session with `allow-passthrough on`, SSH'd into a remote host also running tmux with `allow-passthrough on`
- WHEN the user copies text inside the innermost (remote) tmux pane
- THEN the OSC 52 sequence MUST traverse both tmux layers unmodified
- AND the outermost client terminal's clipboard MUST contain the copied text

#### Scenario: Passthrough missing at one nesting level breaks the chain

- GIVEN one tmux layer in a nested chain does not have `allow-passthrough on`
- WHEN a copy is attempted from an inner pane
- THEN the OSC 52 sequence MUST NOT reach the outer client clipboard
- AND the system MUST document this as an unsupported configuration, not silently degrade to a remote clipboard tool

### Requirement: OpenCode Copy Path Inherits Terminal Contract

The system MUST let OpenCode's OSC 52 copy output flow through the same tmux/SSH/passthrough contract as any other program, without a separate clipboard mechanism.

#### Scenario: OpenCode copy inside tmux over SSH

- GIVEN OpenCode is running inside a tmux session reached over SSH
- WHEN OpenCode emits an OSC 52 write sequence for a copy action
- THEN the sequence MUST follow the same tmux passthrough and SSH transparency path as manual tmux copies
- AND OpenCode's native fallback (`wl-copy`/`xclip`/`osascript`) MUST NOT be relied upon for the remote case

### Requirement: Managed Graphical Terminal Receiver Policy

The system MUST declare and verify OSC 52 write support for each managed graphical terminal (Ghostty, Kitty, Alacritty) against its pinned version before claiming compatibility.

#### Scenario: Ghostty receives OSC 52 writes

- GIVEN Ghostty is configured with explicit OSC 52 write permission
- WHEN a copy action inside tmux or OpenCode emits an OSC 52 write sequence
- THEN Ghostty's native OS clipboard MUST contain the copied text

#### Scenario: Kitty/Alacritty policy is verified, not assumed

- GIVEN Kitty or Alacritty is a managed receiver client
- WHEN the pinned version's OSC 52 write behavior is checked against its documented/tested configuration
- THEN the system MUST record the confirmed policy (supported/unsupported) rather than assume default behavior
- AND MUST NOT claim clipboard support for a receiver whose policy is unverified

### Requirement: MATE/VTE Terminal Documented as Unsupported

The system MUST document that MATE Terminal (VTE-based) does not implement OSC 52 and therefore cannot receive tmux/OpenCode clipboard writes through this channel.

#### Scenario: Copy inside MATE Terminal does not reach OS clipboard via OSC 52

- GIVEN a user runs tmux inside MATE Terminal (VTE)
- WHEN the user copies text via tmux-yank
- THEN the OS clipboard MUST NOT be updated via OSC 52
- AND the system MUST NOT attempt a remote clipboard tool as compensation

### Requirement: Wetty Write-Only Bounded OSC 52 Bridge

The system MUST provide (or verify) a Wetty-side handler that accepts only OSC 52 write sequences, decodes bounded UTF-8 payloads, and calls the browser Clipboard API only within a secure (HTTPS) context after user gesture/consent. The system MUST pin/audit the Wetty image or frontend used to provide this behavior.

#### Scenario: Copy in Wetty session updates browser clipboard

- GIVEN a user accesses tmux through Wetty over HTTPS with a pinned/audited image
- WHEN the user copies text inside the remote tmux session, emitting OSC 52
- THEN the Wetty frontend MUST decode the write payload within its size bound
- AND MUST call `navigator.clipboard.writeText` only in a secure context after focus/gesture
- AND the browser clipboard MUST contain the copied text

#### Scenario: Oversized OSC 52 payload is rejected

- GIVEN a copy action produces an OSC 52 write payload exceeding the configured size bound
- WHEN Wetty's frontend receives the sequence
- THEN the payload MUST be rejected/truncated per documented limit
- AND the browser clipboard MUST NOT be set with a corrupted or partial value

#### Scenario: Non-secure context blocks clipboard write

- GIVEN Wetty is accessed without HTTPS (insecure context) or without a user gesture
- WHEN an OSC 52 write sequence arrives
- THEN the Clipboard API call MUST NOT execute
- AND the system MUST NOT fall back to a remote clipboard tool on the Wetty host

### Requirement: XRDP/MATE cliprdr Reconnection Behavior

The system MUST document and verify `cliprdr` clipboard behavior across XRDP disconnect/reconnect cycles, while ensuring the underlying tmux session and its buffer persist independent of the RDP clipboard channel's state.

#### Scenario: tmux buffer survives XRDP disconnect

- GIVEN a user is copying inside tmux through an XRDP/MATE session
- WHEN the RDP client disconnects (network drop, session lock)
- THEN the tmux session MUST remain running (not cleaned up by `xrdp-session.sh`)
- AND the tmux paste buffer MUST retain the last copied text

#### Scenario: cliprdr state after reconnect is documented, not assumed

- GIVEN a user reconnects to the same XRDP session after a disconnect
- WHEN the user attempts a copy/paste via `cliprdr`
- THEN the system MUST document the verified behavior (whether `cliprdr` clipboard sync resumes automatically or requires a fresh copy)
- AND MUST NOT claim guaranteed clipboard continuity across the RDP channel without a passing reconnect test

### Requirement: kmscon Bounded Console Limit

The system MUST document that kmscon provides no verified external OSC 52 or graphical clipboard receiver, and that recovering copied text from a kmscon-originated tmux session requires reattaching from a supported client.

#### Scenario: Copy inside kmscon has no external clipboard guarantee

- GIVEN a user runs tmux inside kmscon (bare console, no X11/Wayland)
- WHEN the user copies text via tmux-yank
- THEN the system MUST NOT claim the text reached any external/graphical clipboard
- AND the tmux paste buffer MUST still retain the text

#### Scenario: Retrieving a kmscon copy via reattach

- GIVEN text was copied inside a tmux session running under kmscon
- WHEN the user reattaches the same tmux session from a supported client (e.g. SSH + Ghostty)
- THEN `tmux paste-buffer` MUST return the copied text
- AND the client's OSC 52-capable terminal MUST be able to forward it to that client's clipboard

### Requirement: Cross-Platform Client Parity (macOS/Linux)

The system MUST apply the same tmux OSC 52/passthrough configuration on Linux and macOS (Darwin) hosts, so copy behavior for supported receivers does not differ by host OS.

#### Scenario: Same copy contract on Linux and macOS clients

- GIVEN a user copies text inside tmux from a Linux host and, separately, from mact2 (macOS)
- WHEN both use an OSC 52-capable receiver terminal
- THEN both MUST deliver the copied text to their respective native OS clipboard (X11/Wayland clipboard on Linux, pasteboard on macOS)
- AND both MUST use the identical tmux `set-clipboard`/`allow-passthrough` configuration

### Requirement: Explicit Non-Goals Enforcement

The system MUST NOT implement OSC 52 clipboard reads, remote `xclip`/`wl-copy`/`pbcopy` invocation from within a tmux session reached over SSH, X11/Wayland socket/display forwarding for clipboard sync, or any clipboard-synchronization daemon.

#### Scenario: No remote clipboard binary is invoked for a copy action

- GIVEN any copy action originates inside a tmux session reached via SSH
- WHEN the copy completes
- THEN no `xclip`, `wl-copy`, or `pbcopy` process MUST have been spawned on the remote host for that action

#### Scenario: No daemon process exists for clipboard sync

- GIVEN the full clipboard routing contract is deployed across all documented flows
- WHEN the host's running services/processes are inspected
- THEN no persistent clipboard-synchronization daemon MUST be present
