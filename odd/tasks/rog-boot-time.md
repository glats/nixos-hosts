# rog-boot-time
Objective: cut rog boot from ~3m59s; remove stale-swap 90s stall and per-boot Home Manager activation cost (shared by all hosts).
Branch: fix/rog-boot-time | Delivery: ask-on-risk | Runner: go -C pkgs/nixos-scripts test ./..., nix eval, nix flake check --no-build

## Specs
- S1: rog must not wait for the missing swap device `/dev/disk/by-uuid/4474da4a-a080-4b0f-9f9a-74fa0c99dc8a` (hardware-configuration.nix is generated and never edited; zramSwap stays).
- S2: `ai-assets-reconcile` must be a near no-op when the target already matches: skip rewriting files whose current digest already equals the desired content, hash/stream instead of loading whole trees, drop per-file fsync (journal manifest stays durable), and add a "already applied" stamp keyed on desired+legacy+revision+tool version written only after full success. All existing ownership/collision/pending/lock invariants and tests must keep passing.
- S3: `setupOpencodePluginRuntime` must not re-copy `node_modules` every boot when the source store path is unchanged.
- S4: network- and keyring-dependent hooks (`ensureNvimConfig` git fetch, `ghDefaultAccount`) must not block Home Manager activation at boot; they run later with retry (user service), never fatal.
- S5: Differential: ai-assets output (target tree + manifest semantics) is identical to the previous behavior for changed/unchanged inputs.

## Tasks
- [x] T1 S1 inline commit:pending (eval: swapDevices=[] on rog; toplevel drv evaluates)
- [x] T2 S2,S5 inline commit:pending (RED: 4 new tests failed on base; GREEN: aiassets pkg ok; differential vs base binary on 4319-file tree: target trees identical, no-op 10-18s -> 0.07s fast path / 0.8s slow no-op; deviation: per-file fsync kept for changed files for crash-recovery correctness, streaming hash dropped as unnecessary) (Risk item 1: manages user-owned files)
- [ ] T3 S3 inline commit:-
- [ ] T4 S4 inline commit:-

## Log
L1 (2026-11-07) user: "odd para resolver esto. haz un explore para ve la mejor solcuion y sofisticada"
L2 (2026-11-07) user: "apruebo todas las propuestas" (plan: swap override; reconcile skip-identical+stamp; node_modules stamp; move network/keyring hooks to user services)
L3 evidence: journal gap 13.5s->98.1s, run-wrappers.mount After=swap.target, swap UUID 4474da4a absent (nvme0n1 has no partition table); HM service 1m52s of which ~100s in four ai-asset steps; reconcile loop rewrites every file each run (reconcile.go:302-306) with f.Sync() per write (line 131). systemd-tmpfiles-clean is a 15min post-boot timer, not boot path.
L4 note: pre-existing uncommitted change in hosts/rog/home/default.nix (activeProviderName) is unrelated; do not stage.
