# xrdp clipboard self-reconnect (FreeRDP multi-chunk channel reassembly)

Objective: stop the macOS RDP client from tearing down and reconnecting every time something is copied inside the xrdp session on rog, and retain separate server diagnostics.
Branch: master. Delivery: direct master commits and push, no feature flow or activation. Runner: Nix build plus host evaluations; runtime proof remains user-operated.

## Specs

S1. "my xrdp clients get created when I copy" — copying inside the xrdp session on rog must not create a new `xrdp` client child on the server.

S2. "real fix. algo sofistcado" — fix the cause, not the symptom: no clipboard disabling, no `RestrictOutboundClipboard`/`RestrictInboundClipboard` change, no session or launcher change, no xrdp server change as part of the clipboard fix. The later logging request is a separate diagnostic change under S6.

S3. Implementation criterion for S1: valid multi-chunk static virtual channel PDUs must be accepted when accumulated length matches the announced total. Buffer capacity is not the protocol length. Runtime resolution of the reported symptom remains unverified.

S4. The fix must be upstream's 3.32.2 change and nothing else: applying the patch to the pinned freerdp 3.32.0 must reproduce `channels/client/addin.c` byte for byte as published in 3.32.2.

S5. Scope of the clipboard backport: Darwin only, through `overlays/darwin.nix`. Acceptance: `nix build .#darwinConfigurations.macm5.pkgs.freerdp` succeeds and `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` evaluates. The independent S6 diagnostic change does not alter this patch's scope.

S6. "yo creo que mejor haces el cambvio en esta rama y luego yo en rog desplego" — retain main xrdp diagnostics in the journal through the supported configuration hook. Preserve the existing master DEBUG/console configuration and session manager behavior; enable main-daemon syslog without modifying TLS or networking. Deployment remains user-operated.

S7. "dejalo en master. sin feature flow" and "haz commit de todo y push. yo hago deploy" — commit all pending changes directly on master and push, including the previously separate Homebrew edit. Deployment remains user-operated.

## Tasks

- T1 [S1-S5, S7] inline, source/build/evaluation verified on master; earlier source/harness checks remain applicable because the derived package is identical. Runtime acceptance pending. Implementation commit pending recording.
- T2 [S6-S7] inline, source/evaluation verified; existing DEBUG/console settings preserved. Full Linux configuration build and live diagnostics are user-operated and pending. Implementation commit pending recording.

## Log

L1. User: "my xrdp clients get created when I copy"

L2. User: "real fix. algo sofistcado"

L3. Client log signature, three identical occurrences (`~/Library/Logs/remote-rog.log` on macm5, sdl-freerdp 3.32.0):
```
[ERROR][com.winpr.clipboard] ClipboardGetData: No synthesizer for format CF_RAW [0x00000000] --> text/plain [0x0000c000]
[ERROR][com.freerdp.channels.addin] channel_client_post_message: cliprdr_plugin_process_received: read error
[ERROR][com.freerdp.channels.cliprdr.client] cliprdr_virtual_channel_open_event_ex: failed with error 1359
[ERROR][com.freerdp.core] checkChannelErrorEvent: cliprdr_virtual_channel_open_event_ex reported an error. Error was 1359
[ERROR][com.freerdp.client.SDL] Failed to check FreeRDP event handles
[INFO][com.freerdp.common][client_auto_reconnect_ex]: Network disconnect!
```
The `ClipboardGetData` line is on the SDL/AppKit thread; `read error` and 1359 are 3-6 ms later on the cliprdr channel thread.

L4. REFUTED (see L8-L9). First theory: the client stores the payload under local format id 0 and the next local read fails. Evidence used at the time: the temporal proximity of the `ClipboardGetData` line and the 1359.

L5. Upstream survey (2026-11-02): 3.32.2 and master made a failed `ClipboardSetData` non-fatal in `sdlClip::ReceiveFormatDataResponse`, and master adds a name-only branch that covers images only (`mime_is_image(name) || mime_is_bmp(name)`). Bumping the nixpkgs pin was rejected as too wide a closure change.

L6. REFUTED (see L8-L9). Invariants checked for that first theory: the client format list is built from SDL local mime types and never from `clipboard->formats`, so registering a server-announced name cannot cause a re-announce loop; `ClipboardRegisterFormat` is register-or-find; `text/plain` is normally registered at init.

L7. The first patch (`sdl_clip.cpp`, name-only formats plus non-fatal set failure) applied with zero fuzz and built: `nix build .#darwinConfigurations.macm5.pkgs.freerdp` produced the patched derivation. It was never deployed.

L8. User doubt ("estoy un poco dudoso") forced a re-read of the log, which refuted L4: 534 `No synthesizer CF_RAW --> text/plain` lines against only 3 fatal sequences; the 16 `error retrieving clipboard data` lines all follow `CF_DIB [0x8] --> image/tiff [0xc002]`, never the text pair; `error when setting clipboard data` never appears, so that hunk never executed; and the new `xrdp` child at 10:05:04 had no 1359 at all.

L9. Explore subagent mapped the receive path, and I verified its central claim. `cliprdr_plugin_process_received: read error` is emitted only at `channels/client/addin.c:705-708` in the pinned 3.32.0 source:
```c
if (Stream_Capacity(data_in) != Stream_GetPosition(data_in))
```
`channel_client_post_message` allocates the reassembly stream with the first chunk's length only, and `Stream_EnsureCapacity` grows to `size + 128 - size % 128` (`winpr/libwinpr/utils/stream.c:47-72`). Two 1600-byte chunks give capacity `3200 + 128 - 0 = 3328` against position 3200, so the check fails for any multi-chunk PDU; a single-chunk PDU passes because `Stream_New(nullptr, dataLength)` leaves capacity equal to position. That is a static-channel reassembly bug, not a clipboard bug, and it explains the counts: only clipboard payloads above one channel chunk crash. xrdp 0.10.6.1 announces text as format ids 13, 16, 1 and 7 with empty names (`sesman/chansrv/clipboard.c`, `clipboard_send_format_announce`) and answers a request for format id 0 with `CB_RESPONSE_FAIL`, so the `CF_RAW`/`text/plain` pair is a harmless pre-request probe and cannot be the cause.

L10. Fix: backport 3.32.2's reassembly change (`UINT32 totalLength` in `msg_proc_internals`, save it on the first chunk, reject inconsistent totals, compare `totalLength` against the position at the last chunk, reset it). Earlier L4-L7 artifacts removed: `patches/freerdp/clipboard-name-only-formats.patch` deleted.

L11. Not yet deployed: runtime proof on macm5 (copy inside the session, no new `xrdp` child on rog) needs `nixos-build` on macm5, which is not authorized yet.

L12. Evidence correction (2026-11-02): L9 overstates both universality and historical causality. Capacity can exceed the assembled payload length after growth, which reproduces the erroneous check for the illustrated two-chunk case. Actual chunk sizes for the three historical failures were not captured; neither every multi-chunk payload failing nor those copies being large has been established. The exact log signature supports this failure path, not the historical packet boundaries.

L13. Observed verification: `nix build --no-link --print-out-paths .#darwinConfigurations.macm5.pkgs.freerdp` produced `/nix/store/v3d1pvi8s6w17ni59pa54ff25y91cyp4-freerdp-3.32.0` from `/nix/store/gm825d10cgv93ndkqgfj1yqriv7mglbg-freerdp-3.32.0.drv`. Host evaluation produced `/nix/store/9rg1bxlvhka9zz9r7q7vgfspkx2mbd58-darwin-system-26.05.d31953c.drv`. Formatter reported no changes. Two optional derivation-inspection scripts failed because they assumed the JSON shape; this is not a package build failure.

L14. Resume request: "extrae infor de engram igual y continuemos". Retrieved observation 364 and reconciled with this file and HEAD `4888f95674983fb99414a44db65fbfe05543f294`. Observation 363 records the obsolete initial theory; observation 364 also overstated all-multi-chunk causality and called the unactivated fix shipped. Preserve history and correct the current mirror. Risk: item 5 (patched packaged dependency), item 3 (generic static-channel receive code shared beyond cliprdr). Independent verification is required for those concrete risks, not for task size.

L15. Independent verifier session `ses_e636d90ceffeL9FIdCWyqoxAYS`: extracted the actual receive function and linked real libwinpr streams. Baseline valid 1600+1600 and 1600+1600+1600 failed with 1359; patched cases passed at lengths 3200 and 4800. Single 1000 passed both. Inconsistent total and overrun returned 13 in both; short LAST returned 1359 in both. Parent reran both binaries and observed the same results. This proves focused reassembly behavior, not a live xrdp session. Patch applied without fuzz and resulting addin.c matched newly fetched upstream 3.32.2 byte-for-byte. Derivation env.patches includes `/nix/store/qpz036l111pqjdylxfrd4kjh68fv5z8g-channel-reassembly-total-length.patch`; parent cmp confirmed it matches the workspace patch.

L16. `git diff --check` failed on unified-diff context lines (space-before-tab and blank context marker); these bytes are required patch context, not added C whitespace. No cosmetic rewrite applied. Native review mode is globally off; no review lifecycle started and no preference changed. An assessment attempt was unavailable because untracked inventory requires explicit declaration; it does not lower risk or negate the independent checks. Delivery remains disabled/unmanaged.

L17. Focused probe files were external scratch under `/private/var/folders/yh/4_8l_n1x7glg7w1p80yfycz40000gn/T/opencode/vfy.T1AE`; no durable regression runner was added. No activation or live clipboard-copy check was performed. Next gate: user authorization to deploy the patched macm5 client, then live small/large clipboard transfer and client/server log correlation. S1 remains pending; do not mark the feature complete.

L18. Parent removed the verifier-owned scratch directory after the successful spot check. Overlay-only `git diff --check` passed. Workspace scope is unchanged: overlay, new patch and this feature document only.

L19. User: "dale. primero trate todo lo de master y hago despliegue nix build en este worktree". Authorized bringing master into this worktree; deployment is user-operated. Fetched origin/master and fast-forwarded feat/remote from `4888f956` to `a5105ddb`, preserving all three pending feature paths without stash, rebase or a new commit. `git merge-base --is-ancestor origin/master HEAD` passed. Four incoming commits changed seven unrelated paths; FreeRDP source/patch inputs are unchanged.

L20. Post-fast-forward macm5 host evaluation passed: `/nix/store/6rwjxiwj4mvp0nzwdf4xpza3i4ygdqph-darwin-system-26.05.d31953c.drv`. No activation performed. Repository CLI help confirms `nixos-build switch` builds and activates, whereas `nix build` alone does not activate. Explicit `darwin-rebuild switch --flake .#macm5` from this worktree selects this candidate. Live clipboard acceptance remains pending the user's deployment and test.

L21. User: "yo creo que mejor haces el cambvio en esta rama y luego yo en rog desplego". Logging implementation stays in source; no temporary live override or service restart. The main daemon's EnableSyslog setting is the only diagnostic change under this task.

L22. Read-only review on 2026-11-05: live macm5 FreeRDP output `j8389pmvlg5px7fmpv814byhh1bgjmqr` lacks this backport; its derivation includes only SDL patches. New 1359 entries therefore do not establish failure of the verified backport. The log lacks calendar dates for those entries. Rog is logging through DEBUG console output into journald; this differs from the earlier INFO/syslog proposal. Separate TLS/NIC causality remains unproven.

L23. User: "dejalo en master. sin feature flow". Selected the existing master worktree, preserving the original feature worktree. Updated master from `9bdde739` to `7aaad232` with fast-forward only. A pre-existing `darwin/system/homebrew.nix` edit is unrelated and must not be staged or committed. Its SHA-256 before this work is `436d411b42806a5795583f8f55cae85d8fb29bd57f01197907b7386e463f65bf`. Master already contains DEBUG/console logging; preserve it while adding main-daemon syslog.

L24. Master verification (2026-11-05): formatter made no changes; targeted whitespace checks passed. FreeRDP source and derivation are identical to L13/L15, and `nix build --no-link --print-out-paths .#darwinConfigurations.macm5.pkgs.freerdp` again returned `/nix/store/v3d1pvi8s6w17ni59pa54ff25y91cyp4-freerdp-3.32.0`. macm5 host evaluation returned `/nix/store/20g50ys9hk75piswhf4fbdwi52iwcw3i-darwin-system-26.05.d31953c.drv`; rog returned `/nix/store/hw43d2sgb21zb4aps8kdq7mb3ddfwmvy-nixos-system-rog-26.05.20261028.08d3a97.drv`. The Darwin host evaluation includes the human's uncommitted Homebrew edit; the FreeRDP package derivation does not depend on it. Pre-existing rofi/system option-renaming warnings remain. Source comparison proved that removing the added syslog substitution exactly restores master's xrdp module. Native review remains globally off.

L25. Independent verifier `ses_e5390c32affeyNd6glEiAmT15r` loaded the requested skills and found no source-integration blockers across S2-S7. S1 remains runtime-pending. It confirmed the exact original patch, supported hook ordering, preserved DEBUG/console configuration and unchanged Homebrew checksum. No new runtime probe was needed for the identical package; L15 evidence was reused. No server activation, restart or client deployment occurred. Risk: item 3 (shared static-channel receive behavior) and item 5 (packaged dependency and service diagnostics).

L26. User: "haz commit de todo y push. yo hago deploy". This supersedes the earlier no-push scope and authorizes including the existing Homebrew `sloth` addition. Keep RDP and Homebrew in separate Conventional Commits; no deployment or service restart. The Homebrew change was included in the successful Darwin host evaluation from L24; installation is untested.
