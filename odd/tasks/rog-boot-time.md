# rog-boot-time
Objective: cut rog boot from ~3m59s; remove stale-swap 90s stall and per-boot Home Manager activation cost (shared by all hosts).
Branch: fix/rog-boot-time | Delivery: ask-on-risk | Runner: go -C pkgs/nixos-scripts test ./..., nix eval, nix flake check --no-build

## Specs
- S1: rog must not wait for the missing swap device `/dev/disk/by-uuid/4474da4a-a080-4b0f-9f9a-74fa0c99dc8a` (hardware-configuration.nix is generated and never edited; zramSwap stays).
- S2: `ai-assets-reconcile` must be a near no-op when the target already matches: skip rewriting files already owned and identical, and trust an "applied" stamp (kept in the manifest, keyed on desired+legacy+revision+tool version, per-file digest/size/mtime/ctime/inode, racy-window protected) only when every recorded file and source file still matches and no path has a symlinked ancestor. Per-file fsync is kept for files that do change (crash recovery of the Pending journal depends on it); streaming hashes were judged unnecessary. All existing ownership/collision/pending/lock invariants and tests must keep passing; no new reserved file name in the target.
- S3: `setupOpencodePluginRuntime` must not re-copy `node_modules` every boot when the source store path is unchanged.
- S4: network- and keyring-dependent hooks (`ensureNvimConfig` git fetch, `ghDefaultAccount`) must not block Home Manager activation at boot (no user session bus); they run later with retry (user service), never fatal. An interactive switch with a session bus may still run the bounded 5s gh switch.
- S5: Differential: ai-assets output (target tree + manifest semantics) is identical to the previous behavior for changed/unchanged inputs.

## Tasks
- [x] T1 S1 inline commit:1697e367 (eval: swapDevices=[] on rog; toplevel drv evaluates)
- [x] T2 S2,S5 inline commit:3557f01f+fix pending (RED: 4 new tests failed on base; GREEN: aiassets pkg ok; differential vs base binary on 4319-file tree: target trees identical, no-op 10-18s -> 0.07s fast path / 0.8s slow no-op; deviation: per-file fsync kept for changed files for crash-recovery correctness, streaming hash dropped as unnecessary) (Risk item 1: manages user-owned files)
- [x] T3 S3 inline commit:f1cf646f (home activationPackage rog builds; shell logic COPIED/SKIPPED verified in scratch; tradeoff: manual edits to node_modules persist until package store path changes or .nix-source removed)
- [x] T4 S4 inline commit:1dfa49b4 (gh check passes incl. new no-bus case; hm eval rog/thinkcentre/t14/samsung + nixos eval x4 + flake check --no-build ok; darwin not evaluable on x86_64 (platform mismatch, same on base); user units rendered and syntax-checked)

## Log
L1 (2026-11-07) user: "odd para resolver esto. haz un explore para ve la mejor solcuion y sofisticada"
L2 (2026-11-07) user: "apruebo todas las propuestas" (plan: swap override; reconcile skip-identical+stamp; node_modules stamp; move network/keyring hooks to user services)
L3 evidence: journal gap 13.5s->98.1s, run-wrappers.mount After=swap.target, swap UUID 4474da4a absent (nvme0n1 has no partition table); HM service 1m52s of which ~100s in four ai-asset steps; reconcile loop rewrites every file each run (reconcile.go:302-306) with f.Sync() per write (line 131). systemd-tmpfiles-clean is a 15min post-boot timer, not boot path.
L4 note: pre-existing uncommitted change in hosts/rog/home/default.nix (activeProviderName) is unrelated; do not stage.
L5 verifier (gentle-ai-verify, baseline 87f3985a) found 3 blockers in T2: (1) mtime+size stamp ignored same-size edits with restored mtime; (2) fast path skipped symlinked-ancestor check; (3) new reserved `.gentle-ai-owned.stamp` name could clobber a user file and rejected a source file of that name. S1,S3 met; S4 advisory: bus-present activation still waits up to 5s on gh (baseline behavior); nvim clone synchronous (baseline advisory).
L6 correction (one batch): stamp moved into the manifest (`applied`, no new file name); fingerprint and per-file records now include ctime+inode and the racy window covers max(mtime,ctime); fast path runs safePath per directory; interrupted-journal drops the stamp; verifier regression cases added as tests (all pass, also verifier's exact probes run in scratch with racyWindow=0). S2 and S4 rewritten to match. nvim clone given a 60s timeout.
L7 native review (lineage review-e77daa97db5a6310, lenses risk+reliability, base 1697e367..HEAD committed-only): consent granted by user; both reviewer tasks were refused by the OpenCode review transport twice (`opencode_review_transport_relay_refused: reviewer_result_not_admissible`), so no review verdict exists. Outcome: unavailable; independent verifier (L5/L6) stands as the high-risk check. Lineage left in `reviewing` state (no acknowledgement possible).
L8 pending: real reboot of rog to measure boot time (expected userspace ~1.5min lower from swap removal alone; HM activation expected to drop from ~1m52s to a few seconds after the stamp is established, which takes two boots because of the racy window).
