# Repaired native Mac source, configuration and full builds pass

The approved #3979 repaired candidate passes the three native Mac evaluations, explicit native binary/assets aggregate build, full Darwin system plus standalone Home Manager build, integrated HM closure check, and actual generated permissions/provider projection. This report applies to repaired fingerprint `80c3f4be999c87e20eccb35521d5fdcae5c0e33a8ac0b98ffb52282987aea4fd`, not the previous `3229…` snapshot. No activation or organic runtime/model/provider/MCP testing occurred. Common progress/tasks were intentionally left for parent integration.

## Exact source receipt

| Item | Value |
|---|---|
| Actual baseline HEAD | `4750736cd68f517a871ac7448639c94546472390` |
| Authoritative repair receipt | `/home/glats/.local/opencode-v2/tmp/opencode/repaired-v4-fingerprint.json` |
| Reviewed owned fingerprint | `80c3f4be999c87e20eccb35521d5fdcae5c0e33a8ac0b98ffb52282987aea4fd` |
| Archive SHA-256 | `3c2f8c1f8c6a56536462741692fdfca3bdbd4a604e316cd48c26ccad0d8997b6` |
| Manifest SHA-256 | `7042f4bf01f58b328c14a56195f18d5a5dff5f654cda7478ceb00891a117a047` |
| Remote fresh private source | `/Users/juan/.cache/gentle-ai-v4-candidate.repaired.lky947p9/source` |
| Local evidence directory | `/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-mac-candidate/repaired-handoff-lky947p9` |

Packaging reused the validated temporary source-only fixture with a separate repaired receipt/directory namespace. It used `git archive` of actual HEAD plus exactly the 31 approved owned overlays/deletions, including new files and three deleted files. The archive has 845 regular source files. Foreign dirty tracked work, user host selections and unrelated untracked OpenSpec work were excluded; the Mac source retains baseline-selected `openai-anthropic-go`. The original snapshot/directory/report remain untouched. Prior `github:glats/nixos-hosts/4750736cd68f517a871ac7448639c94546472390` bootstrap and candidate lock are preserved.

Paths/modes were validated without symlink traversal, absolute/parent paths, special permission bits or private-key/auth/database filenames. No home/runtime/auth directory or `.git` was packaged. Tracked encrypted SOPS files were copied as opaque source bytes, never decrypted or interpreted/displayed. The repaired acceptance-spec artifact is outside the 31 source allowlist and was not overlaid into this source-only bundle; its separate hash remains in the authoritative receipt.

Strict direct `juan@macm5.local` SSH used existing trusted host records, BatchMode and ConnectTimeout 10; no new host-key acceptance, SSH/key/known-host changes or relay operation occurred. The remote directory was newly created mode 0700, never overwriting the original snapshot or habitual checkout. Native identity checks were Darwin/arm64/juan. Archive checksum and safe member prefix checks passed before extraction; manifest checksum passed afterward. All 845 source file hashes and owned deletion/symlink checks passed both before and after gates.

## Native gates and outputs

All commands returned exit 0. Evaluations and the package aggregate had 360-second own-client watchdogs; the full system/HM aggregate had a 1,500-second own-client watchdog. No bound was reached; watchdogs were canceled. Normal public dependency fetching was allowed without model/catalog requests. All commands preserved the lock, and builds created no result links.

| Gate | Exact result |
|---|---|
| macm5 system drvPath | `/nix/store/s4lfzz180jmm5ghqmms456jf7yv00yf8-darwin-system-26.05.c3e90c8.drv` |
| Integrated juan HM drvPath | `/nix/store/5njx8957zwm78q422cx0mg9177m3k5kx-home-manager-generation.drv` |
| Standalone macm5 HM drvPath | `/nix/store/fyfzp1mv2lssmlwjh5drkcvcpk0vl5m8-home-manager-generation.drv` |
| Native Gentle output | `/nix/store/67fvc0dr6y82skcwh9x8jib5wpyrb7hx-gentle-ai-4.0.0` |
| Native assets output | `/nix/store/0gzd3gg0fp9znbf38mvishyx2kycdd0r-gentle-ai-assets-4.0.0` |
| Full Darwin system | `/nix/store/nl62ff5clnq25p35mw739q0pdcg5v6yk-darwin-system-26.05.c3e90c8` |
| Standalone HM generation | `/nix/store/hajm8p40zzzb17yj6rn984mpvsqvin0l-home-manager-generation` |
| Integrated HM generation | `/nix/store/xgfzynhgz6i567vg9n9rkqq2dkx3ycxx-home-manager-generation` |

The full build scheduled 10 derivations, including changed native OpenCode JSON, both HM generations and the system. Binary/assets store paths remain stable because their canonical package inputs did not change; the explicit aggregate command nevertheless ran successfully on repaired source. The changed system/HM outputs and actual native JSON projections, not the old binary paths alone, establish repaired configuration proof. All three full generation paths are valid under `nix path-info`; integrated HM is a member of the system's recursive closure.

Actual commands from the remote private source directory:

```sh
NIX=/nix/var/nix/profiles/default/bin/nix
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.drvPath
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#gentle-ai path:.#gentle-ai-assets
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#darwinConfigurations.macm5.config.system.build.toplevel path:.#homeConfigurations.macm5.activationPackage
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.outPath
```

## Actual native generated permissions and provider declaration

Read-only native Nix evaluation projected only selected profile, agent mode/model/permission rows and the NVIDIA alias from both targets' generated `.config/opencode-v2/opencode.json`. It also projected names from the repaired provider source. No credentials, settings/header values or saved account/runtime data were requested. The projection SHA-256 is `56f27397832fc06a774dc4f3002d354abb7fbdef00e6f6772c4d2b24c924f9da`.

Both targets are equal, with 16 agents and selected profile `openai-anthropic-go`. Their model/permission rows exactly equal the historical #3963 rows, now checked again against repaired generated JSON. Last-matching permission assertions pass: read-only roles deny edits; managed subagents/general deny delegation; worker/fix/general allow edits; the orchestrator denies wildcard unknown routes and explicitly permits managed routes.

There are exactly 32 unique profile names. `opencode-free`, `anthropic-opencode-free` and `anthropic-opencode-go` are absent. Both actual generated native declarations contain:

```json
"nemotron-3-ultra-550b-a55b": {
  "name": "Nemotron 3 Ultra",
  "modelID": "nvidia/nemotron-3-ultra-550b-a55b"
}
```

Two initial projection query shapes incorrectly selected the flake default package instead of its output set; they failed before returning configuration. The corrected explicit read-only `--impure --expr`/`builtins.getFlake` projection passed. These are harness query errors, not candidate failures, version workarounds or native build retries. The retained query error log discloses them.

## Evidence and boundary

Evidence in the local directory includes `handoff-identity.json`, `source-manifest.json`, the archive/checksum, `transfer.log`, `source-before.log`, `native-gates.log`, `native-grants.json`, `native-grants-verification.json`, `native-grants-query-error.log`, `native-grants.stderr`, `source-after.log` and `closure-check.log`. Engram #3987 records source transfer, #3994 native builds and #3995 native generated permission/profile proof.

The earlier unchanged renderer's initial three-second discovery failure and later unchanged successful reprobe remain historical evidence in `native-mac-check.md`; no cause/fix, timeout increase, CLI/SDK update, artificial cache flush, prewarming or organic compatibility certification is claimed. This run used existing valid native build cache normally.

No product source changes, activation, login/auth access or copying, models/provider/MCP calls, services/relay-policy changes, commits/push/index/ref mutation or existing checkout writes occurred. This worker's authorized native build scope is distinct from the separately authorized rog isolated-login/live worker. Common task completion, repaired Linux gates, organic behavior and fleet rollout/rollback remain for the parent to integrate; this report certifies only the listed source/configuration/native build subgates.
