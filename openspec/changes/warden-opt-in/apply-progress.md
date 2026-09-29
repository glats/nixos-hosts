# Apply Progress: Warden Opt-In (Default-Off)

## Status

7 of 10 tasks complete. Tasks 3.2, 3.3, and 3.7 remain pending because the requested macm5 evaluations require an `aarch64-darwin` derivation and cannot be evaluated on this `x86_64-linux` evaluator.

## Completed Tasks

- [x] 1.1 Declare `home.opencode.plugins.warden.enable` with `mkEnableOption`.
- [x] 1.2 Derive the V1 npm plugin list with a default-priority Warden entry.
- [x] 2.1 Gate the managed Warden JSON file on the enable flag.
- [x] 3.1 Format the two changed Nix modules.
- [x] 3.4 Verify opt-in output on rog and t14.
- [x] 3.5 Verify V2, active plugins, and offline package pins remain unchanged.
- [x] 3.6 Run the flake check.

## Pending Tasks

- [ ] 3.2 Complete the default-off V1 JSON assertion for macm5.
- [ ] 3.3 Complete the disabled Warden-file assertion for macm5.
- [ ] 3.7 Complete macm5 Home Manager and nix-darwin activation-package evaluation.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `nix eval --impure --json --expr …extendModules… | jq -e …` passed for rog and t14 (`true`, exit 0). Corrected default V1 source-content assertion passed for rog, thinkcentre, and t14 (`true`, exit 0). The task's `.text` selector evaluates to `null` because V1 uses `source`, not `text`. |
| Runtime harness command/scenario and exact result | N/A — this declarative option has no runtime boundary. The managed-file lifecycle is represented by the conditional Home Manager declaration; a disposable macOS activation requires an aarch64-darwin evaluator. |
| Rollback boundary | Revert `shared/opencode/plugins.nix` and `shared/opencode.nix`; no store pin, V2 serializer, or host override changed. |

## Verification Results

- `nix fmt -- shared/opencode/plugins.nix shared/opencode.nix`: exit 0; formatted 1 file with 0 changes after the final edit.
- `nix flake check --no-build`: exit 0; `all checks passed!` (aarch64-darwin and x86_64-darwin omitted as incompatible systems).
- rog, thinkcentre, and t14 activation-package drvPath evaluations: exit 0.
- macm5 Home Manager and nix-darwin drvPath evaluations: failed with `Required system: 'aarch64-darwin'; Current system: 'x86_64-linux'` while realizing `gentle-ai-assets`.
- macm5 Warden-file assertion: failed for the same platform mismatch while evaluating the complete `home.file` attrset.
- V2 generated JSON and `activePlugins` match the committed baseline; Warden pin files have no diff.
- A `rog.extendModules` evaluation with `warden.enable = true` and an explicit two-base-plugin `npmPlugins` assignment returned `override-preserved`.
