# Roadmap

Parent map for this repository's active product lines. Direction, capabilities, dependencies and
delivery boundaries live here; each feature owns its own document under `odd/tasks/`.

## rom-catalog

Product: one web place to pick a game by platform, ordered, with good galleries, and to download
ROMs into the library that RomM already serves.

Feature owner: `odd/tasks/rom-catalog.md`

| Delivery | Scope | Host | URL | Status |
| --- | --- | --- | --- | --- |
| D1 | RomM gallery hardening: cover/metadata providers, artwork priority, filesystem watcher, scheduled rescan | `rog` | `https://roms.glats.org` | in progress |
| D2 | `romcatalog` Go service: Internet Archive catalog, platform picker, cover gallery, resumable verified downloads into the library | `rog` | `https://rom.glats.org` | pending (source policy decision open) |
| D3 | Platform to emulator/core map, optional MCP endpoint for assistants | `rog` | `https://rom.glats.org` | pending |

Boundaries: `rog` only, no new host. RomM stays the library (metadata, screenshots, in-browser
play); `romcatalog` is the discovery and acquisition front-end. Downloads land in the same library
disk that RomM scans, so a downloaded game shows up in RomM without a second copy.

Dependencies: D2 needs D1's scan pipeline (watcher plus scheduled rescan) to surface downloaded
ROMs, and D1's provider configuration for the gallery.

Standalone application: the user approved initializing [ROMHarbor](https://github.com/glats/romharbor)
as a separate public MIT-licensed repository, based on `glats/web-base`. The repository has been
created and the verified application foundation is published on `main` at `2e373abd425a`.
`make test` and `make lint` passed. Native review could not start because of its context budget;
the user authorized reporting the failure and continuing without review for that candidate.
Catalog extraction and migration have not started. This configuration repository keeps deployment wiring
and the library layout; do not duplicate the new application's task ledger here.

Destination planning: `docs/rom-destinations.md` maps all current catalog platforms to emulator
candidates and host/handheld folders. `rog` remains the source of truth. Selected games may later
be copied to playing hosts over SSH/HTTP or to the Powkiddy V90S over a supported network route
or SD card. This map does not authorize installs, transfers, SD changes or the separate app.
Runtime emulator inventory, device connectivity and per-game launch proof remain pending.

## Gas Town on rog

Product: direct a new or existing project by conversation. Give OpenCode the intent and any base documentation, answer functional or architectural questions, and ask what was delivered, how to verify it, and what needs a decision. Today the operator dictates with Gboard into a terminal through Windows App, WireGuard and XRDP. The goal is to do the same by voice without opening a remote desktop.

| Delivery | Acceptance | Owner |
| --- | --- | --- |
| First: diagnose one delivery (read-only) | Tell the operator what was requested, what was delivered, which checks actually ran, what remains unverified and who needs to decide. Identify what OpenCode, Gas Town, Nix and local Go each contributed. | [Host foundation, T5](tasks/gastown-host-foundation.md) |
| D0: Go/Nix gate | Run the same offline check locally and before Gas Town accepts changes here. It must reject the historical Darwin host-entry bypass, accept the valid import and explain the fix. A lint pass is not a functional test. | [Host foundation, T1–T2](tasks/gastown-host-foundation.md) |
| D1: declarative host setup | Nix declares campaign settings. On a clean host, prepare missing state; on a used host, preserve progress, `STOP` and manual start. Verify the host configuration without activating it. | [Host foundation, T3–T4](tasks/gastown-host-foundation.md) |

The diagnosis sets the next improvement; it does not remove lint or Nix from the foundation. First prove the conversation works in text using the [existing campaign loop](tasks/swarm-campaigns.md). Mobile voice is a later interface to that same flow. The phone channel (campaign T7) stays on standby; no app or transport is selected. Provider chains and the [subscription study](tasks/subscription-plan-evaluation.md) stay in their existing ledgers. No campaign launch or host activation is part of this handoff.
