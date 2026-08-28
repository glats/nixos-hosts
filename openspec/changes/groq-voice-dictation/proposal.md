# Proposal: Groq Voice Dictation

## Intent

Provide lightweight, hosted Spanish voice dictation on Linux without local models, while restoring the missing PipeWire runtime required for XRDP microphone forwarding on `rog` and `thinkcentre`.

## Scope

### In Scope
- Add a packaged `groq-dictation` command: capture audio, convert to 16 kHz mono WAV, call Groq, and insert the returned text.
- Transcribe Spanish through `/audio/transcriptions` using `whisper-large-v3-turbo`; provide `--translate` through `/audio/translations` using `whisper-large-v3`.
- Reuse only the existing encrypted `opencode/groq_api_key`/`GROQ_API_KEY`; never expose it in logs, arguments, or the Nix store.
- Wire MATE/XRDP (`rog`, `thinkcentre`) hotkeys and `xdotool` insertion; wire Hyprland (`t14`) hotkeys and `wtype` insertion.
- Enable PipeWire, WirePlumber, and rtkit on `rog` and `thinkcentre` so the installed XRDP source/sink modules can create `xrdp-source` in microphone-enabled RDP sessions.

### Out of Scope
- macOS dictation or changes to `mact2`; native dictation remains untouched.
- Local Whisper/Vosk models, streaming, diarization, or a general configurable Nix service.
- Darwin FreeRDP `/microphone` client support; this change covers Linux-host session dictation only.

## Capabilities

### New Capabilities
- `groq-voice-dictation`: Hosted Spanish transcription/optional English translation with session-appropriate text injection on Linux.
- `xrdp-pipewire-audio-runtime`: PipeWire runtime support for XRDP microphone forwarding on MATE hosts.

### Modified Capabilities
None; existing `boot` and `hardware-nvidia` requirements are unrelated.

## Approach

Package a small `bin/groq-dictation` through `pkgs/nixos-scripts`: select capture source, record and normalize audio, POST with an explicit User-Agent, then use `xdotool` for X11/XRDP or `wtype` for Wayland. Redact `gsk_`/`sk-` values, skip empty recordings, report missing sources clearly, and honor `Retry-After` for 429s.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `bin/groq-dictation`, `pkgs/nixos-scripts/default.nix` | New/Modified | Dictation command packaging |
| `linux/system/base/audio.nix`, host imports | New/Modified | PipeWire runtime on rog/thinkcentre |
| `linux/home/suites/mate/mate-dconf.nix` | Modified | MATE hotkeys |
| `hosts/t14/home/omarchy.nix` | Modified | Hyprland hotkeys |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| XRDP client disables microphone redirection | Medium | Detect absent source and give actionable error |
| Translation uses unsupported turbo model | Low | Pin translations to `whisper-large-v3` |
| Secret or synthetic-input failure | Medium | Redaction, no argv secret, backend-specific checks |

## Rollback Plan

Remove the command, bindings, and new audio-module imports; reverting PipeWire restores the prior XRDP behavior without changing secrets or macOS.

## Dependencies

- Existing `opencode/groq_api_key`; Groq hosted API; `ffmpeg`, capture tools, `xdotool`, and `wtype`.

## Success Criteria

- [ ] All Linux hosts dictate Spanish without a local model; `--translate` writes English.
- [ ] XRDP MATE sessions expose `xrdp-source` when the client forwards a microphone.
- [ ] mact2 and shared Darwin modules remain unchanged; flake evaluation passes for all hosts.
