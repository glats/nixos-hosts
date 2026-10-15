# Final candidate native build readiness passes

Task 3.3 is ready for parent integration at final owned-source fingerprint `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb`: the completed final Linux shared/evaluation/build/schema evidence is current, and a fresh source-only final snapshot now passes native Darwin evaluations and full Darwin/standalone Home Manager builds. This is configuration/build readiness, not activation, organic runtime compatibility, account entitlement or live model/MCP certification. Common tasks/progress remain unchanged.

## Exact identity and preserved history

| Item | Verified value |
|---|---|
| Actual repository HEAD | `4750736cd68f517a871ac7448639c94546472390` |
| Current authoritative receipt | `/home/glats/.local/opencode-v2/tmp/opencode/repaired-v4-fingerprint.json` |
| Final 31-entry compact-manifest SHA-256 | `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb` |
| Final snapshot archive SHA-256 | `00714f537454af21ef86306ffe57198c76fe7231a4555c4ba0a4a6bb5d36d738` |
| Final full-source manifest SHA-256 | `27d3a71e4367fb3b7b2a3c6c2c90023157a5c9029963062ab2bd81f18faf44f1` |
| Fresh native source | `/Users/juan/.cache/gentle-ai-v4-candidate.final.b7g1_531/source` |
| Local final evidence | `/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-mac-candidate/final-handoff-b7g1_531` |
| Preserved historical repaired source | `/Users/juan/.cache/gentle-ai-v4-candidate.repaired.lky947p9/source` |

The final source was freshly assembled from `git archive` of actual HEAD plus exactly the 31 owned entries, including new files and three deletions. It contains 845 regular source files, not 845 files plus 31 additional files. All non-owned content comes from the baseline; foreign dirty tracked files, unrelated untracked work and worktrees were not copied. The acceptance spec remains a separately verified companion hash, not an additional source overlay. Comparing the historical repaired and fresh final full-source manifests shows exactly one changed path, `flake.nix`, for the SDD-to-ODD schema-check role correction.

Local HEAD, unchanged receipt bytes, all 31 owned entries and the acceptance-spec hash were guarded before and after each remote command. Remote archive/manifest checksums, all 845 file hashes, the 31 owned entry conditions, all three deletion absences, file count and absence of symlinks passed before and after gates. Safe relative archive members were checked locally before packaging; archive checksum and member-prefix/traversal checks passed remotely before extraction. Tracked encrypted SOPS files were transferred only as opaque source bytes, never decrypted or displayed. No home, runtime, account or Git metadata was copied.

Direct `juan@macm5.local` SSH used `BatchMode=yes`, `StrictHostKeyChecking=yes` and `ConnectTimeout=10` with existing trust, without modifying SSH keys/config/known-hosts or using a relay. Native identity was verified as Darwin/arm64/juan. A fresh cache parent was created with umask 077, preserving every historical snapshot and the habitual checkout. Final local recheck also verified raw index diff SHA-256 `89dfdbb95e7ce6359c3835e659285ec01ca06587b1086c43110d9a60581ca6f6`; the user's primary rog selection remains `openai-medium`.

## Final Linux evidence reused, not first-repair proof

Retrieved the actual Engram observations: **#3992** is the final repaired Linux/schema discovery and **#3993** is its session summary. Both identify final `12d82f…`, not historical `80c3f4…`. Their proof matches [model-catalog-check.md](model-catalog-check.md), “Completed gates, schema-check regression and final fingerprint,” and the actual external `catalog-retirement-preview/3979-6chRUIOi/final-verification.json` receipt. The receipt SHA-256 is `1e08afe06bc881265adc92204c701f7ded652366bfbd454efbd1745d36bd64c6`.

That completed final run spans **2026-10-09T17:54:13.340500Z–18:00:56.512674Z**, exit 0: shared `nix flake check --no-build`, nine Linux system/integrated-HM/standalone-HM derivation evaluations, all six native system/standalone-HM builds and actual built agent-schema assertions passed. No old system output was substituted: the final schema correction changed Linux system derivations and the runner rebuilt the six targets. This continuation reuses that matching final-source evidence rather than rerunning or claiming new Linux execution.

| Final evaluated Linux target | Derivation |
|---|---|
| rog system | `/nix/store/if873i67pl7pc01qp9faxl3yq9d4iw51-nixos-system-rog-26.05.20260822.a9e6d84.drv` |
| rog integrated HM | `/nix/store/s2hpc1r8rvcqp86l9qlpigwlp2915vpz-home-manager-generation.drv` |
| rog standalone HM | `/nix/store/czgfdkxyhgny5z6iipk6gqs2y5zdglc3-home-manager-generation.drv` |
| thinkcentre system | `/nix/store/97hq57si2a8861m7kl676d66xalws72m-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv` |
| thinkcentre integrated HM | `/nix/store/ysbkvqv73dkvhz29s49xkn3mgqm5abxx-home-manager-generation.drv` |
| thinkcentre standalone HM | `/nix/store/iqcj3a5hza6ljha95qxkpmj0332mlpp0-home-manager-generation.drv` |
| t14 system | `/nix/store/xxdy1q2rkwk5ds65nnc963gxw2jjgv20-nixos-system-t14-26.05.20260822.a9e6d84.drv` |
| t14 integrated HM | `/nix/store/fvivc81c8sv8sbn1bv6lx4nbqn3xjmg8-home-manager-generation.drv` |
| t14 standalone HM | `/nix/store/nbzrlz7g4pmpjhd566hld9l23sk9ka28-home-manager-generation.drv` |

| Final native Linux build | Output |
|---|---|
| rog system | `/nix/store/8abvgyjjsqswfxmlnlkjsriympazp86b-nixos-system-rog-26.05.20260822.a9e6d84` |
| rog standalone HM | `/nix/store/lzmimq0lygglp1wvsb4zm44nwbrgfydf-home-manager-generation` |
| thinkcentre system | `/nix/store/k9l956ab70ld9xky4q8prvjmayc5rkbg-nixos-system-thinkcentre-26.05.20260822.a9e6d84` |
| thinkcentre standalone HM | `/nix/store/fq7z75vghbr1akhx4pdgn8mvzzm3c4hq-home-manager-generation` |
| t14 system | `/nix/store/7a6g2y81jpcb71j3kb103cs3hfp8x28l-nixos-system-t14-26.05.20260822.a9e6d84` |
| t14 standalone HM | `/nix/store/csf3k2xmnjcl7414ym9ayhhvl3g8y1bh-home-manager-generation` |
| Built agent-schema check | `/nix/store/i0kjvrx62zzajn1vnmsgfq5f6jyql34z-opencode-v2-agent-schema` |

The schema derivation is `/nix/store/hvjk9fwd3xi6av0b1lshkqgfngnfj0g6-opencode-v2-agent-schema.drv`. Focused ownership/graph/launcher and 24 Bun transport tests remain documented by the Linux worker; they are not new organic runtime proof.

## Fresh final native Mac gates

The actual final-source native run completed **2026-10-09T18:22:18.961676Z–18:22:57.519329Z**. Every recorded command returned exit 0, with no retries or timeouts. The foreground scratch runner returned exit 0. Both aggregate builds used `--no-link --no-write-lock-file`; no result links, lock changes or activation occurred.

| Gate | Exact final result |
|---|---|
| Darwin macm5 system drvPath | `/nix/store/s4lfzz180jmm5ghqmms456jf7yv00yf8-darwin-system-26.05.c3e90c8.drv` |
| Integrated juan HM drvPath | `/nix/store/5njx8957zwm78q422cx0mg9177m3k5kx-home-manager-generation.drv` |
| Standalone macm5 HM drvPath | `/nix/store/fyfzp1mv2lssmlwjh5drkcvcpk0vl5m8-home-manager-generation.drv` |
| Explicit native Gentle build | `/nix/store/67fvc0dr6y82skcwh9x8jib5wpyrb7hx-gentle-ai-4.0.0` |
| Explicit native assets build | `/nix/store/0gzd3gg0fp9znbf38mvishyx2kycdd0r-gentle-ai-assets-4.0.0` |
| Full Darwin build | `/nix/store/nl62ff5clnq25p35mw739q0pdcg5v6yk-darwin-system-26.05.c3e90c8` |
| Standalone HM build | `/nix/store/hajm8p40zzzb17yj6rn984mpvsqvin0l-home-manager-generation` |
| Actual integrated HM output | `/nix/store/xgfzynhgz6i567vg9n9rkqq2dkx3ycxx-home-manager-generation` |

All five output paths pass actual native `nix path-info`. A separate recursive-only command at **2026-10-09T18:26:05.038050Z–18:26:05.568033Z**, exit 0, explicitly confirms the integrated HM path in the system's 776-entry recursive closure by exact line equality. Its isolated output is retained in `recursive-only.stdout`. This avoids mistaking the integrated path printed by the preceding five-path validity query for recursive membership; the initial combined output remains in `closure.stdout`.

The measured final Mac derivations and outputs equal historical `80c3f4…` paths. That equality was **not assumed** and does not borrow its proof: all evaluations and builds executed against the newly transferred final snapshot. Normal valid native build cache explains the quick build run; no recompilation, artificial cache flush, prewarming, dependency upgrade or provider request is claimed. Linux system paths changed under the same flake-only fix, so neither platform's behavior was inferred from the other.

Actual native commands, from the final source directory:

```sh
NIX=/nix/var/nix/profiles/default/bin/nix
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.drvPath
"$NIX" eval --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.drvPath
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#gentle-ai path:.#gentle-ai-assets
"$NIX" build --no-write-lock-file --no-link --print-out-paths path:.#darwinConfigurations.macm5.config.system.build.toplevel path:.#homeConfigurations.macm5.activationPackage
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.outPath
"$NIX" eval --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.outPath
"$NIX" eval --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.outPath
"$NIX" path-info /nix/store/nl62ff5clnq25p35mw739q0pdcg5v6yk-darwin-system-26.05.c3e90c8 /nix/store/xgfzynhgz6i567vg9n9rkqq2dkx3ycxx-home-manager-generation /nix/store/hajm8p40zzzb17yj6rn984mpvsqvin0l-home-manager-generation /nix/store/67fvc0dr6y82skcwh9x8jib5wpyrb7hx-gentle-ai-4.0.0 /nix/store/0gzd3gg0fp9znbf38mvishyx2kycdd0r-gentle-ai-assets-4.0.0
"$NIX" path-info --recursive /nix/store/nl62ff5clnq25p35mw739q0pdcg5v6yk-darwin-system-26.05.c3e90c8
```

| Recorded command group | Exit codes |
|---|---|
| Native identity/private-directory creation | 0 |
| Archive transfer; manifest transfer; checksum/extraction | 0; 0; 0 |
| Full source verification before gates | 0 |
| System; integrated HM; standalone HM drv evaluations | 0; 0; 0 |
| Gentle/assets aggregate; full Darwin/standalone aggregate | 0; 0 |
| Integrated; system; standalone output-path evaluations | 0; 0; 0 |
| Five-path validity plus recursive system closure | 0 |
| Full source verification after gates | 0 |
| Separate recursive-only closure membership confirmation | 0 |

`events.json` retains the initial runner's exact SSH commands, start/end timestamps and exit codes. `final-native-proof.json` binds those events to the final fingerprint, snapshot hashes, actual derivations and outputs, and separately records the recursive-only command/timestamps/exit/membership proof. Separate stdout/stderr files retain all command results. All report derivation/output paths were mechanically checked against the Linux and Mac receipts; local owned inputs remained unchanged. Engram **#4001** records the fresh final-source Mac proof.

## Acceptance and scope boundary

Task 3.3's shared no-build check, three Linux systems and integrated HM evaluations, Darwin system and integrated HM evaluations, all four standalone HM evaluations and native platform builds are evidenced at the final owned identity. There is no remaining task-3.3 evaluation/build deficit; the parent may integrate the result without silently certifying later gates.

The historical native renderer three-second discovery failure/successful unchanged reprobe and historical generated-grants proof remain in their original reports. This continuation did not run the native TUI, initialize an SDK/server, inspect accounts/auth, invoke models/providers/MCP, alter permissions or certify organic compatibility. Separate login/live authorizations #3979/#3983 were not inherited. No activation, service/policy changes, staging/commits/push or existing checkout writes occurred. Only this owned repository report was added; product inputs, fingerprints, index, common progress and tasks were left unchanged.
