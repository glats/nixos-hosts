# Native Linux full build verification — 2026-10-09

PASS: all three native Linux full systems (`rog`, `thinkcentre`, `t14`), their integrated `glats` Home Manager dependencies, and all three standalone Home Manager generations built successfully. No activation occurred. This closes the native Linux build component of task 3.3; the parent owns the aggregate task/progress update. It does not establish organic runtime/model/MCP behavior, deployment or actual fleet rollback.

## Source and public host selection

The worker ran on Linux x86_64 in the primary `/home/glats/.nixos` checkout. Actual HEAD was `4750736cd68f517a871ac7448639c94546472390`. Before evaluation, all 31 entries (including three deletions) matched `/home/glats/.local/opencode-v2/tmp/opencode/final-v4-fingerprint.json`, whose reviewed owned-content manifest SHA-256 is `3229f4238f8a9071e4790e8db6f781c60f80aff29e86f2083f9f471d8f783ed3`.

Every installable used `path:/home/glats/.nixos#`, not the default Git flake, so newly added/untracked implementation files were included. Current foreign/user host changes were retained, not rolled back. Both integrated and standalone public `home.opencode.activeProviderName` evaluations returned `openai-medium` for `rog`, and `openai-anthropic-go` for `thinkcentre` and `t14` (all six exit 0). No account, credential or authentication metadata was inspected.

The successful aggregate's full source snapshot is `/nix/store/qg1c5dphfcn806c6n1aqzwfj3lljjc9y-source`, present in each built system closure. All 31 reviewed entry hashes/deletions were verified directly in this immutable source. Every initially fingerprinted public configuration/code file outside `docs/` and `openspec/` also matched that built source. Native Mac evidence shares the reviewed 31-owned-file identity, not an identical full checkout: its handoff excluded foreign changes, whereas this Linux build includes them.

## Evaluation results

All nine `drvPath` evaluations and all nine corresponding `outPath` evaluations returned exit 0. For each row the exact commands were:

```sh
nix eval --no-write-lock-file --raw "path:/home/glats/.nixos#${attribute}.drvPath"
nix eval --no-write-lock-file --raw "path:/home/glats/.nixos#${attribute}.outPath"
```

The attributes were `nixosConfigurations.<host>.config.system.build.toplevel`, `nixosConfigurations.<host>.config.home-manager.users.glats.home.activationPackage`, and `homeConfigurations.<host>.activationPackage`, for each of the three hosts.

| Host / evaluated target | Initial evaluated drvPath | Initial expected output |
|---|---|---|
| rog system | `/nix/store/6ravg7nx37296n5957v0085bmgwaj9xw-nixos-system-rog-26.05.20260822.a9e6d84.drv` | `/nix/store/7333z53bycd4izwizrqhm8s6rbl9qbk2-nixos-system-rog-26.05.20260822.a9e6d84` |
| rog integrated HM | `/nix/store/47vlwwkdsv5kkzrj1j64jh5jbkqciil2-home-manager-generation.drv` | `/nix/store/fw23m5hhhhx1g3zig4gjvfaxn5kscaih-home-manager-generation` |
| rog standalone HM | `/nix/store/i889g12zws624hkzq16xfddq5sc59ias-home-manager-generation.drv` | `/nix/store/fvysv1njg64qjqkh12r8x22x7cs2pk55-home-manager-generation` |
| thinkcentre system | `/nix/store/4s164d25yfp0c0irs4wsc5xzca2whyis-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv` | `/nix/store/vgxgpqz0r7z233sw7jjvjkbclxba03jl-nixos-system-thinkcentre-26.05.20260822.a9e6d84` |
| thinkcentre integrated HM | `/nix/store/725n6fk7fbz28ghdwp92w922y3kz7wzf-home-manager-generation.drv` | `/nix/store/4adrizsr5vyv4kgg8lnzx5y19yq1svwp-home-manager-generation` |
| thinkcentre standalone HM | `/nix/store/qsnvd11hv6z46fyf3ad5x049phdlw2s5-home-manager-generation.drv` | `/nix/store/srxi1sbpfg0iahmbkggdbahwv4p2qsch-home-manager-generation` |
| t14 system | `/nix/store/6l9rpa8w5ww3vsd4j3a6486gi4a9ry8d-nixos-system-t14-26.05.20260822.a9e6d84.drv` | `/nix/store/yf4qi5k3z05ir41fcsj6d9hfr79zf1d4-nixos-system-t14-26.05.20260822.a9e6d84` |
| t14 integrated HM | `/nix/store/a1hq7qgvwj9qarvq5g59whc2kb2127v8-home-manager-generation.drv` | `/nix/store/nhdjci6sq43p4rznidbc08fv9m9481iq-home-manager-generation` |
| t14 standalone HM | `/nix/store/3c9inp8pgkdq1ypgyp9l9afdidv9n9n8-home-manager-generation.drv` | `/nix/store/f6s3d2njfwm6bjwa525ddygllxs5k8h3-home-manager-generation` |

System derivation identities changed between path-source snapshots; the initial expected system outputs above are not claimed built. The system configuration retains source inputs through `linux/system/base/nix.nix:98–118`, including `self`, so unrelated tracking/source snapshot changes affect full-system closure identity. The actual successful outputs and their store-reported derivers below are authoritative. All HM derivations/outputs stayed identical. No production/public configuration or reviewed owned content drift was observed.

## Disk preflight and aggregate build

Initial filesystem space was 617,126,924,288 bytes available. The public-fetch six-target dry-run returned exit 0: 793 derivations to build and 954 paths to fetch, 3.5 GiB download / 10.5 GiB unpacked. After dry-run, 615,668,449,280 bytes remained. This provided ample cache, source-snapshot and build headroom; no GC, root operation or disk workaround was used.

The exact aggregate command, run first with `--dry-run` added, was:

```sh
nix build --no-link --no-write-lock-file --print-out-paths \
  path:/home/glats/.nixos#nixosConfigurations.rog.config.system.build.toplevel \
  path:/home/glats/.nixos#homeConfigurations.rog.activationPackage \
  path:/home/glats/.nixos#nixosConfigurations.thinkcentre.config.system.build.toplevel \
  path:/home/glats/.nixos#homeConfigurations.thinkcentre.activationPackage \
  path:/home/glats/.nixos#nixosConfigurations.t14.config.system.build.toplevel \
  path:/home/glats/.nixos#homeConfigurations.t14.activationPackage
```

The first aggregate reached its 3,500-second client watchdog (exit 124, 3,500.671 seconds); its final stdout was empty and it is not a PASS. The specific client was terminated and reaped, leaving no orphan worker CLI. Its only recorded error was the resulting `error: interrupted by the user`, not a package/test failure. A subsequent public-fetch dry-run returned exit 0 with 29 derivations remaining. The same six-target command then completed in **131.786 seconds, exit 0**, before its 1,750-second watchdog. No blind network retry, pin change, safety bypass or product fix was needed. Final free space was 602,669,580,288 bytes.

All six actual outputs were independently checked with `nix path-info --json <output>` (exit 0). Their derivers were read from store metadata, not inferred from stdout position alone:

| Host / built target | Actual built drvPath | Actual valid output |
|---|---|---|
| rog system | `/nix/store/r0i0c7cr9s8sjqzczndfa3jdibvb5c7n-nixos-system-rog-26.05.20260822.a9e6d84.drv` | `/nix/store/z96mz4igq8rc8pg49ngzppah1dk3papd-nixos-system-rog-26.05.20260822.a9e6d84` |
| rog standalone HM | `/nix/store/i889g12zws624hkzq16xfddq5sc59ias-home-manager-generation.drv` | `/nix/store/fvysv1njg64qjqkh12r8x22x7cs2pk55-home-manager-generation` |
| thinkcentre system | `/nix/store/bldhc3pyi5jwxja2w7k1a7jy0qzm6274-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv` | `/nix/store/z36zgzm1ax1hprfcnqqpgzdh7q141n42-nixos-system-thinkcentre-26.05.20260822.a9e6d84` |
| thinkcentre standalone HM | `/nix/store/qsnvd11hv6z46fyf3ad5x049phdlw2s5-home-manager-generation.drv` | `/nix/store/srxi1sbpfg0iahmbkggdbahwv4p2qsch-home-manager-generation` |
| t14 system | `/nix/store/kdybs7b5gfcpvjx7z089w8rmd4sl228s-nixos-system-t14-26.05.20260822.a9e6d84.drv` | `/nix/store/xim5icgjgjxzflrl0jfpvrprjski6l6m-nixos-system-t14-26.05.20260822.a9e6d84` |
| t14 standalone HM | `/nix/store/3c9inp8pgkdq1ypgyp9l9afdidv9n9n8-home-manager-generation.drv` | `/nix/store/f6s3d2njfwm6bjwa525ddygllxs5k8h3-home-manager-generation` |

Each integrated HM output from the evaluation table was independently valid under `nix path-info --json` and an exact member of its respective successful full-system `nix path-info --recursive <system-output>` closure (all six commands exit 0). This proves all three integrated generations were built as dependencies, not merely evaluated. Closure logs and integrated metadata are retained.

## Evidence and final preservation check

External evidence directory: `/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-native-linux-3961`. It contains per-host/target `drvPath` and `outPath` evaluation logs, `evaluations.json`, six public-profile logs, `aggregate-dry-run.log`, initial watchdog stdout/stderr/result, `resume-dry-run.log`, successful `aggregate-resume.stdout`, `aggregate-resume.stderr`, `aggregate-resume-result.json`, `built-targets.json`, three system closure logs and three integrated-HM metadata files. Initial public-source hashes and exact index bytes were preserved externally for comparison.

Final source/HEAD/index checks and `git diff --check` are recorded in `final-preservation-check.log`. The worker edits only this report; shared progress/tasks, production files, index, refs and foreign work are untouched. Engram observation #3968 records preflight, the truthful timeout and subsequent complete native build proof. No authentication reads, secrets decryption, model/provider/MCP runtime call, activation, service operation, staging, commit or push occurred. Existing generations remain active.
