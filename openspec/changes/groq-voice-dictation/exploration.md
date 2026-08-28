# Exploration: Groq-hosted voice dictation across all hosts

## Current State

### Groq STT API (verified — Context7 + official Groq console docs + prior art)

- **Endpoints** (OpenAI-compatible, multipart form-data):
  - Transcribe: `POST https://api.groq.com/openai/v1/audio/transcriptions`
  - Translate→English: `POST https://api.groq.com/openai/v1/audio/translations`
- **Models** (official console `speech-to-text` capability table — authoritative):
  | Model | Lang | Transcription | Translation | Cost/hr | WER |
  |---|---|---|---|---|---|
  | `whisper-large-v3` | multilingual | ✅ | ✅ | $0.111 | 10.3% |
  | `whisper-large-v3-turbo` | multilingual | ✅ | ❌ | $0.04 | 12% |
  | `distil-whisper-large-v3-en` | English only | ✅ | ❌ | $0.02 | 13% |
- **Translation model difference (key for the "Spanish speech → English text" mode)**: the `/audio/translations` endpoint requires `whisper-large-v3`. `whisper-large-v3-turbo` does **not** support translation. The Context7 SDK autodoc for `client.audio.translations.create` lists *both* models, but the official console capability table is unambiguous — Spanish→English MUST use `whisper-large-v3`. Flag to re-verify at implementation time.
- **`language` param**: ISO-639-1 (`es`), improves accuracy and latency; auto-detected if omitted. The translations endpoint only accepts `en` (target).
- **Formats**: mp3, mp4, mpeg, mpga, m4a, wav, webm, ogg, opus, flac. Groq downsamples to 16 kHz mono server-side; WAV/FLAC 16 kHz mono recommended for lowest latency.
- **Limits**: 25 MB free tier / 100 MB dev; minimum billed 10 s; >30 s recommended. Rate limits for whisper models: **20 RPM, 2K RPD, 7.2K audio-seconds/hour, 28.8K audio-seconds/day**; 429 responses carry `retry-after` + `x-ratelimit-*` headers.
- **No streaming, no diarization, no per-word confidence** — text only.
- **Prior-art gotchas (verified via GitHub issues)**:
  1. Groq keys are `gsk_…`; error sanitizers commonly redact `sk-` but forget `gsk_`, leaking the key into user-facing errors (stablyai/orca#10593).
  2. Groq's Cloudflare edge rejects `Python-urllib`/default-curl `User-Agent` with `403 error code: 1010`; a real `User-Agent` header is required (mvanhorn/last30days-skill#983).
  3. Request shape is OpenAI-compatible; reuse `model` / `file` / `response_format` / `language`.

### Codebase

- **Groq key already exists and is shared**: `sops.secrets."opencode/groq_api_key"` (mode `0400`) in `shared/sops.nix`; exported as `GROQ_API_KEY` in the zsh `initContent` of `shared/opencode.nix`. Both `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix` import `shared/sops.nix` + `shared/opencode.nix`, so the key reaches rog/t14/thinkcentre **and** mact2 today. No new secret is required.
- **XRDP audio is half-wired**: `pkgs/pipewire-module-xrdp/default.nix` builds the neutrinolabs PipeWire sink/source modules and installs an XDG autostart `.desktop` (into `$out/etc/xdg/autostart`). It is added to `environment.systemPackages` on rog (`hosts/rog/default.nix:206`) and thinkcentre (`hosts/thinkcentre/default.nix:84`). **However there is NO `services.pipewire.enable`, `sound.enable`, `hardware.pulseaudio`, or `security.rtkit.enable` anywhere in the tree.** PipeWire/wireplumber is never started, so the XRDP `xrdp-source` (client→server microphone) and `xrdp-sink` (server→client output) never materialize. Audio capture in XRDP sessions is effectively non-functional today and must be enabled as a prerequisite.
- **MATE = X11**: `linux/system/services/xrdp.nix` enables `services.xrdp` with `defaultWindowManager` = the `xrdp-mate-session` wrapper around `mate-session`; `xrdp-session.sh` sets `XRDP_SESSION=1`, `DESKTOP_SESSION=mate`. MATE runs on X11 (`services.xserver.enable = true`), so text injection uses `xdotool`.
- **MATE dconf / hotkey home**: `linux/system/base/dconf.nix` (gated by `my.desktop.suite == "mate"`) and `linux/home/suites/mate/mate-dconf.nix`. Existing global shortcut precedent: `org/mate/marco/global-keybindings` `run-command-1 = <Control>space` → rofi. This is the natural place for a dictation hotkey.
- **t14 = Hyprland/Wayland**: `hosts/t14/home/omarchy.nix` imports omarchy-nix + fragments; keyboard is `es,latam` (`hosts/t14/home/hypr/input.nix`); bindings via `wayland.windowManager.hyprland.settings.bind`. No X11 — text injection uses `wtype` (Wayland). fcitx5 present (input method). PipeWire **is** running on t14 via omarchy-nix, so local mic capture works out of the box there.
- **mact2 = macOS (nix-darwin)**: `hosts/mact2/default.nix`. macOS ships native dictation (Siri). The shared `GROQ_API_KEY` env reaches mact2 but no dictation tool is forced there.
- **No existing dictation tool**: no `whisper`, `nerd-dictation`, or Groq CLI is installed. nixpkgs has the building blocks: `python3.13-groq` (official SDK 1.1.2), `xdotool` (X11), `wtype` (Wayland), `ffmpeg`. `hyprwhspr-rs` and `whisper-cpp` exist but are local-model oriented (rejected). No off-the-shelf "Groq dictation" frontend exists in nixpkgs.
- **Script packaging pattern**: `bin/*.sh` scripts are packaged by the `pkgs/nixos-scripts/default.nix` derivation (installed to `$out/bin`). Custom packages live under `pkgs/<name>/default.nix` (e.g. `pipewire-module-xrdp`). HM-level per-user scripts use `home.file.<path>.text`/`.source`.

## Affected Areas

- `shared/sops.nix` — **no change** (key `opencode/groq_api_key` already declared). Reference only.
- `shared/opencode.nix` — **no change** (`GROQ_API_KEY` already exported). Reference only.
- `linux/system/base/audio.nix` — **NEW** (or fold into an existing base module): `services.pipewire.enable = true` + `wireplumber` + `security.rtkit.enable = true`, gated to Linux desktop hosts. Prerequisite for XRDP mic capture on rog/thinkcentre.
- `linux/system/services/xrdp.nix` — ensure `pipewire-module-xrdp` autostart actually loads (it does once PipeWire runs); optionally verify `xrdp-source` appears.
- `pkgs/groq-dictation/default.nix` (or `bin/groq-dictation` via `pkgs/nixos-scripts`) — the dictation engine: capture → ffmpeg to 16 kHz mono → Groq → inject text. This is the core new artifact.
- `linux/system/base/dconf.nix` or `linux/home/suites/mate/mate-dconf.nix` — MATE hotkey binding (X11 path).
- `hosts/t14/home/omarchy.nix` (and/or a `hosts/t14/home/hypr/*.nix`) — Hyprland bind + `wtype` injection (Wayland path).
- `linux/system/base/profiles/mate.nix` / `profiles/core.nix` — add `xdotool` (MATE) to packages.
- `hosts/mact2/default.nix` — **no change** (preserve native macOS dictation; Groq dictation stays out of scope on darwin).
- `overlays/linux.nix` — only if a new `pkgs/` derivation is added; else the `bin/` + `nixos-scripts` route needs no overlay change.

## Approaches

1. **Custom Groq dictation script + per-platform injection (recommended)**
   - One small shell/Python script: record a short clip (`parecord`/`pw-cat`/`pw-record`), transcode via `ffmpeg` to 16 kHz mono WAV, POST to Groq `/audio/transcriptions` (or `/audio/translations` for English mode), then type the text with `xdotool type` (X11) or `wtype` (Wayland). Reads key from `GROQ_API_KEY` env or the sops secret path; sets an explicit `User-Agent`; redacts `gsk_` in all error output.
   - Pros: zero new deps beyond `ffmpeg`/`curl`/`python3-groq`/`xdotool`/`wtype`; exact fit to "Groq hosted, no local Whisper"; Spanish transcription + optional Spanish→English via a `--translate` flag; matches existing `bin/` + `nixos-scripts` pattern; cross-host by injecting the right `type` backend per session type.
   - Cons: a new custom script to maintain; must handle two injection backends and two session types.
   - Effort: **Medium**.

2. **Full declarative Nix module (`services.groq-dictation` / `home.groq-dictation`) with options**
   - Expose options (`enable`, `model`, `translateToEnglish`, `hotkey`, `recordSeconds`), wire the capture + API + injection and the per-host hotkey from Nix, installed as a first-class `pkgs/` derivation.
   - Pros: most maintainable, matches AGENTS.md "document Nix module options interface" design rule; per-host override pattern already used (`home.opencode.activeProviderName`).
   - Cons: larger diff; more surface to review.
   - Effort: **High**.

3. **Retarget an existing STT dictation frontend to Groq**
   - Patch `whisper-dictate`/`hyprwhspr-rs`/`nerd-dictation` to use Groq's OpenAI-compatible endpoint instead of a local model.
   - Pros: reuses mature capture/typing UX.
   - Cons: those tools are architected around local models (Vosk/faster-whisper); adding a remote backend is invasive; `hyprwhspr-rs` is Hyprland-only (does not cover MATE); heavy to vendor/patch in a Nix repo.
   - Effort: **High**.

## Recommendation

**Approach 1, packaged as Approach 2's options module only if the change grows.** Start with a single `bin/groq-dictation` script (packaged via the existing `pkgs/nixos-scripts` derivation) plus two thin wiring points:

- **Prerequisite (MUST)**: enable PipeWire + WirePlumber + rtkit on the Linux desktop hosts via a new `linux/system/base/audio.nix` imported by rog and thinkcentre. Without this, the XRDP `xrdp-source` never appears and microphone redirection cannot reach the dictation script. t14 already has PipeWire via omarchy-nix.
- **Engine** (`bin/groq-dictation`, with `groq-dictation` entry added to `pkgs/nixos-scripts/default.nix`):
  - `record` N seconds from the session's default source (detect `xrdp-source` vs local mic automatically via `pw-dump`/`pactl`), write to a temp file, `ffmpeg -ar 16000 -ac 1` to WAV.
  - `transcribe` → `POST /openai/v1/audio/transcriptions` with `language=es`, `model=whisper-large-v3-turbo` (default, cheapest multilingual).
  - `--translate` → `POST /openai/v1/audio/translations` with `model=whisper-large-v3` (only model with translation support).
  - `type` → `xdotool type --delay 10` when `$XDG_SESSION_TYPE == x11` / `$XRDP_SESSION == 1`, else `wtype` when `$WAYLAND_DISPLAY` is set.
  - Key source: `GROQ_API_KEY` env (already exported) or `${sops secret path}`; never hardcode.
- **Hotkeys**: MATE — bind a free `<Super>`/`<Control>` combo in `linux/system/base/dconf.nix` (X11). Hyprland — add a bind in `hosts/t14/home/omarchy.nix` (Wayland). Provide a `--translate` variant bound to a second combo.
- **macOS**: leave native dictation untouched; the shared `GROQ_API_KEY` remains available but no dictation tool is installed on mact2 (scope = preserve, not extend).

### Recommended minimal behavior (safety)

- Read the API key from env/sops path only; set `User-Agent: groq-dictation/<version>` (avoids Cloudflare 403 `error code: 1010`).
- Redact `gsk_…` **and** `sk-…` in every error/log line (prior art leak, orca#10593).
- On `429` honor `retry-after` and back off; on `401`/`403`/network timeout print a clean message and exit non-zero without crashing the session or leaking the key.
- Skip API call when recording is empty or < 0.01 s (Groq min); do not bill for silence.
- If no capture source is found (e.g. `xrdp-source` missing because the RDP client disabled mic redirection), fail with "no microphone source — enable audio input redirection in your RDP client" rather than a silent empty transcript.
- Keep `response_format=json` (text only) for minimal parsing; `temperature=0`.

## Risks

- **XRDP microphone redirection depends on both ends**: the server must run PipeWire + `pipewire-module-xrdp` (missing today), and the *client* must enable audio-input redirection (MS-RDPEAI). Remmina profiles already set `microphone = "sys:pulse"`, but the Darwin FreeRDP launcher (`darwin/home/remote-desktop.nix`) only passes `/sound:sys:mac`, **no `/microphone`** — mact2→rog/thinkcentre dictation needs a client-side flag added if cross-host dictation over RDP is desired.
- **Translation model mismatch**: if the English mode is wired to `whisper-large-v3-turbo`, Groq returns a 400/model-capability error. Must pin `whisper-large-v3` for `/audio/translations` and verify against the live API (Context7 SDK autodoc is ambiguous here).
- **Enabling PipeWire on rog/thinkcentre is a system-level change** that could affect existing (currently nonexistent) audio and the MATE volume tray; must be scoped to the Linux desktop hosts and verified with `nixos-build safe`/`--dry`.
- **Two injection backends** (xdotool vs wtype) with subtle differences (IME/accents, focus stealing, key repeat) — Spanish accented characters must round-trip as UTF-8; fcitx5 on t14 can intercept synthetic input.
- **API cost/latency**: dictation is interactive; the 10 s minimum billing and 20 RPM limit bound the design (short clips, no polling loop). Groq is fast (<2 s for short clips) so latency is acceptable, but cost is per-minute-rounded-up.
- **Secrets hygiene**: the key is already in every interactive shell env via `initContent`; the dictation script must not add new exposure (no key in logs, no key in process argv, no key in Nix store derivations).
- **macOS**: no change is the requirement; risk is accidentally dragging a Linux-only dependency into `darwin/home/shared-modules.nix`.

## Acceptance Criteria

- [ ] A dictation engine (script/derivation) transcribes Spanish speech via Groq on all three Linux hosts, with no local Whisper model or download.
- [ ] Optional `--translate` mode emits English text from Spanish speech using `whisper-large-v3` (`/audio/translations`).
- [ ] PipeWire + WirePlumber + rtkit enabled on rog and thinkcentre; `xrdp-source` visible in a MATE XRDP session after the RDP client enables mic redirection.
- [ ] Dictation injects text in MATE (X11 via `xdotool`) and in Hyprland (Wayland via `wtype`).
- [ ] The Groq key is sourced only from the existing `opencode/groq_api_key` sops secret / `GROQ_API_KEY`; `gsk_` is redacted in all errors; a real `User-Agent` is set.
- [ ] Safe error behavior: 429 backoff, 401/403/timeout clean messages, empty-recording skip, missing-source message.
- [ ] mact2 native dictation is untouched; no dictation tool installed on darwin; `darwin/home/shared-modules.nix` unchanged.
- [ ] `nix flake check --no-build` passes for rog, t14, thinkcentre, mact2.

## Proposed change slug

`groq-voice-dictation`

## Ready for Proposal

**Yes** — the scope is well-bounded and the API is verified. The orchestrator should tell the user: (1) the existing `opencode/groq_api_key` secret is reused (no new secret); (2) enabling PipeWire on rog/thinkcentre is a required prerequisite, and (3) cross-host dictation *over RDP from mact2* additionally needs a `/microphone` flag on the Darwin FreeRDP launcher — clarify whether that client-side path is in scope or whether dictation is only expected *inside* each host's own session.

---

## Current-Scope Addendum (2026-08-24): macOS Spanish→English translation

**Why this section exists.** The prior analysis treated macOS as out of scope ("preserve native Dictation"). A new concern surfaced: macOS native Dictation does **not** translate Spanish speech into English text — it transcribes in the spoken language only. This section evaluates how to obtain Spanish→English on macOS and compares three approaches. It is purely additive: it does **not** change the proposal, the Linux plan, or any code above.

### Verified facts (MCP research first)

- **macOS native Dictation cannot translate.** Apple Support (`support.apple.com/guide/mac-help/mh40584`, "Dictate messages and documents on Mac") documents Dictation as same-language transcription with multi-language *switching* ("Dictate in another language"), not translation. There is no speech→foreign-text mode. Apple's Translate app and Apple Intelligence Writing Tools operate on **text**, not live speech. The user's concern is confirmed.
- **Groq `/audio/translations` does exactly this, server-side.** Context7 (`/groq/groq-python`) confirms `client.audio.translations.create(model=…, file=…)` returns English text from foreign-language audio. The SDK autodoc accepts both `whisper-large-v3` and `whisper-large-v3-turbo`, but the official Groq console capability table (cited above) marks translation as `whisper-large-v3` **only** — the ambiguity persists and must be pinned at implementation.
- **Open-source macOS dictation clients exist but do NOT translate.** GitHub search surfaced vocamac, MiniWhisper, dictly, inputalk, sussurro, CustomWispr, openwhisper-app, YapToText, aidictation, SottoASR, MyVoiceTyping. All are menu-bar apps using on-device Whisper/Parakeet (local, keyless) that **transcribe in the spoken language**; none add a translation step. They ship via Homebrew/App Store (Swift/Go/Rust), **not nixpkgs**, so they sit outside this repo's declarative model.
- **macOS text injection is solved but permission-heavy.** All of the above type into the focused app via clipboard + `Cmd+V` (`CGEvent`) or the Accessibility API (`AXUIElement`) — both need the **Accessibility** TCC grant; audio capture needs **Microphone** TCC; global hotkeys via `CGEventTap` need **Input Monitoring** (avoidable with `NSEvent.addGlobalMonitor`, gated on Accessibility alone). TCC is keyed to the app's **code identity/bundle ID**: a real `.app` bundle with `NSMicrophoneUsageDescription` + the `com.apple.security.device.audio-input` entitlement + codesigning is required; ad-hoc-signed hardened-runtime builds **fail silently** without entitlements, and CLI scripts get permission attributed to the invoking terminal, not the binary (SottoASR architecture doc; djmunro/hush `docs/macos-permissions.md`; Hairizuan Swift-dictation write-up).

### Approach comparison (macOS Spanish→English)

| Dimension | (A) Per-client Groq call | (B) ROG-hosted translation proxy | (C) Open-source/local macOS client |
|---|---|---|---|
| **Typing into focused app** | Yes — needs a macOS client (TCC Accessibility) | Yes — same macOS client | Yes (native feature) |
| **TCC permissions** | Microphone + Accessibility (+ hotkey) | Same | Same (+ Input Monitoring for hotkey) |
| **API-key exposure** | Groq key already on mact2 (shared sops) — no new exposure | Key stays on rog; mact2 gets a scoped client key | None (local Whisper) — but also no translation |
| **Secure audio transport** | mact2→api.groq.com (TLS) | mact2→rog over WireGuard/TLS | None (on-device) |
| **Authentication** | Groq bearer key | Scoped client key + WireGuard peer, or nginx+Authelia (`opencode-proxy` precedent) | None (local) |
| **Latency** | ~1–2 s (Groq) | ~1–2 s + one LAN/WG hop (negligible) | Model load + local inference (slow on Intel, fast on Apple Silicon) |
| **Maintenance** | One thin shared client (mirrors Linux `bin/groq-dictation`) | + new service, + client-key secret, + vhost | Adopt/update a third-party app (Homebrew, not Nix) |
| **Solves Spanish→English?** | **Yes** (`/audio/translations`) | **Yes** (same endpoint) | **No** — transcribes only; needs a bolted-on translation step |
| **Effort** | Low | Medium | High |

1. **(A) Per-client Groq calls with shared sops key** — a thin macOS client (or the existing `bin/groq-dictation` adapted) records the mic, POSTs to `https://api.groq.com/openai/v1/audio/translations` with `whisper-large-v3`, and injects the English text into the focused app. `opencode/groq_api_key` is already on mact2 via `shared/sops.nix` + `shared/opencode.nix`, so **no new secret, no new service**. This is the direct extension of the existing Linux plan.
   - Pros: minimal new surface; key already present; translation is one API call; no server to run.
   - Cons: still requires building/obtaining a macOS audio-capture + text-injection client, and the TCC/codesigning burden applies regardless of where the audio goes.
   - Effort: **Low**.

2. **(B) Private ROG-hosted authenticated audio translation proxy** — a loopback (or WireGuard-bound) service on rog holds the Groq key and exposes `/v1/audio/translations` (+ transcriptions), mirroring `linux/system/services/web/opencode-proxy.nix` exactly (inline Python, hardened systemd sandbox, sops key files, scoped client key). mact2 reaches it over WireGuard (`mac` peer `10.13.13.3` → `10.13.13.1`, AllowedIPs `10.13.13.0/24, 172.16.0.0/24`) or nginx+Authelia.
   - Pros: key never leaves rog for *new* clients; single place for rate-limit/logging/redaction; serves future low-trust clients (phones/tablets) without exposing the Groq key.
   - Cons: **the Groq key is already on mact2's disk today**, so for the primary (mact2) use case this yields no real exposure reduction; adds a service + secret + vhost to build and maintain; speculative until a non-mact2 client exists (YAGNI).
   - Effort: **Medium**.

3. **(C) Open-source/local macOS client** — install a Swift/menu-bar dictation app (vocamac, MiniWhisper, dictly, …) running Whisper on-device.
   - Pros: fully local, keyless, no cloud, native typing UX, no Groq dependency.
   - Cons: **none translate** — Spanish speech yields Spanish text, so the stated need (English output) is still unsolved without adding a translation step (a Groq/LLM call, which reintroduces A/B) or a local translation model (heavy). Also Homebrew-cask distribution breaks this repo's declarative single-source-of-truth, and the apps are immature (tens of stars, weeks old).
   - Effort: **High**.

### Recommendation (ponytail/YAGNI)

**Approach (A) — per-client Groq `/audio/translations` with the already-shared sops key — is the laziest correct answer, and it is the one to take if macOS Spanish→English dictation is actually wanted.**

- The Groq key is **already on mact2** (`shared/sops.nix`), so (B)'s headline benefit (key isolation) is already null for this host. Building (B) now is speculative infrastructure for clients that don't exist yet — defer it until a phone/tablet client actually lands, and reuse `opencode-proxy.nix` when that happens.
- (C) does not solve the problem: open-source macOS dictation apps transcribe but do not translate, and adopting one still leaves the translation gap plus a non-declarative install path.
- Native Dictation is genuinely insufficient for the translation goal, so "do nothing" is not an option *if* translation is required on macOS.

**The real decision is scope, not architecture.** The cheapest option of all is to **keep macOS out of the translation scope** (as the original plan already did) and add a macOS client only if the user explicitly confirms they need Spanish→English dictation *natively on mact2*, as opposed to dictating over RDP into a Linux session (already covered by the Linux plan). If macOS translation is confirmed: build the thin macOS client against approach (A). If not: no macOS code changes at all.

### macOS-specific risks (new)

- **TCC is the dominant cost.** Any macOS client — (A) or (B) — needs a signed `.app` bundle with `NSMicrophoneUsageDescription`, the `com.apple.security.device.audio-input` entitlement, and a manual Accessibility grant. A hardened-runtime, ad-hoc-signed bundle without entitlements fails **silently** (no prompt, no TCC entry). This burden is identical for (A) and (B) and is the largest maintenance item.
- **CLI-script TCC attribution.** A bare `bin/groq-dictation` script on macOS would have mic/Accessibility permission attributed to the invoking terminal app, not the script — expect a first-run grant dance and possibly a reboot to clear cached TCC state.
- **Translation model pinning.** `whisper-large-v3-turbo` appears in the Context7 SDK autodoc for `translations.create`, but the console capability table says translation is `whisper-large-v3`-only. Pin `whisper-large-v3` and verify against the live API; a 400 model-capability error on the wrong model is the expected failure mode.
- **No new key exposure.** Approach (A) adds no secret. Approach (B) would add a scoped client key (following the existing `openai_proxy/client_key` pattern, whose `.sops.yaml` creation rule already includes the mact2 host key). Do not introduce a second Groq credential.
- **Homebrew drift.** Choosing (C) bypasses Nix entirely (Homebrew cask + manual updates), breaking this repo's reproducibility and single-source-of-truth.
