```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:ab2cd98d9fbaeb95c03b30a130c2e8ad35ca7236b623436b9dd235c6ee3b4602
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 6/6
scenarios: 6/6
test_command: "nix flake check --no-build"
test_exit_code: 0
test_output_hash: sha256:9d1adf091fef4f80ae81e5cec4c4d980a05eb7631a995a18961cce333440a06a
build_command: "nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link --dry-run"
build_exit_code: 0
build_output_hash: sha256:2ce86e0ca9e6c4d973e1264aa279cc5f53b7c9fd68ef66f2079367b2d26d3724
```

## Verification Report

Change: `prune-declared-builtin-providers`

Mode: hybrid, standard verification. The updated delta specification contains six requirements and six scenarios; all seven implementation tasks are checked complete.

### Re-verification

The only change since the previous verification report is the delta specification's replacement of stale literal counts with dynamic baseline criteria. No provider implementation changed. The final baseline was `a4a5564607e777a8f6ce36ff590009e86a96d7aa`; it differs from the requested `ae5b172` only through an unrelated committed skill rename, not the provider files.

| Scenario | Verdict | Current runtime evidence |
|---|---|---|
| Generated catalog excludes built-in model pins | PASS | Evaluated `allProviders` is `["nvidia","opencode"]`. `opencode` has only `options`, whose keys are `["chunkTimeout","timeout"]`; it has no `models`, and no NVIDIA model has `thinking`. |
| Pruned and baseline routing are equivalent | PASS | `/tmp/opencode/verify2/harness.nix` imports the current immutable baseline via `builtins.fetchGit`, uses the pinned nixpkgs lib `a9e6d84`, serializes each complete `providers` list with `builtins.toJSON`, and compares the full JSON strings. It reports `profilesIdentical=true`, baseline/candidate counts `25/25`, the same 12 phase keys, and equal JSON SHA-256 `adb5a1cc9ccfc9f6ab01ecc97517c24c57c20ea0441130a6d48000808b1f0d59`. |
| Free routing retains one-hour limits | PASS | Source evaluation reports exactly `timeout=3600000` and `chunkTimeout=3600000` under option-only `provider.opencode`; the current t14 toplevel dry-run passed. |
| Dead extension path is grep-clean | PASS | `git grep -n -E 'extraProviders|anthropicProvider|githubCopilotProvider|providers-extra' -- ':!openspec/**'` returned no code matches (exit 1), and `providers-extra.nix` is deleted. |
| Built-in credentials survive pruning | PASS | `git diff --quiet HEAD -- shared/opencode.nix` exited 0; no sops-backed export changed. |
| Repository and provider checks pass | PASS | `format-nix --check`, `nix flake check --no-build`, the full A/B evaluation, live catalog cross-check, and t14 toplevel dry-run all passed. |

### Gates

| Gate | Result | Evidence |
|---|---|---|
| Formatting | PASS | `format-nix --check` exited 0; output hash `sha256:2bc21bb3c1ffba4a4715c136878b53208e27567efb438c23971c26b202ab6456`. |
| Flake evaluation | PASS | `nix flake check --no-build` exited 0; output hash `sha256:9d1adf091fef4f80ae81e5cec4c4d980a05eb7631a995a18961cce333440a06a`. |
| t14 evaluation | PASS | `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link --dry-run` exited 0; output hash `sha256:2ce86e0ca9e6c4d973e1264aa279cc5f53b7c9fd68ef66f2079367b2d26d3724`. |
| Full JSON A/B identity | PASS | Current-HEAD baseline and working tree serialize to the same complete profile JSON; every baseline profile is byte-identical. |
| Live catalog resolution | PASS | `curl -fsS https://models.dev/api.json` checked 30 unique built-in references: anthropic 4, github-copilot 10, openai 7, opencode 4, opencode-go 5. `missing=[]`, `missingCount=0`; NVIDIA remains explicitly declared. Catalog result hash: `sha256:47635aa12593d01fb92b60834918612230abd8458155d0b6e7fa827c5ca74bc4`. |
| Consumer grep | PASS | No references to `extraProviders`, `anthropicProvider`, `githubCopilotProvider`, or `providers-extra` outside OpenSpec. |
| Provider shape | PASS | Only `nvidia` and option-only `opencode` are declared; no configured OpenCode models or `thinking` keys remain. |
| Diff scope and credential stability | PASS | `git diff --name-only HEAD` contains exactly `shared/opencode/providers-base.nix`, `shared/opencode/providers.nix`, and `shared/opencode/providers-extra.nix`; `shared/opencode.nix` is unchanged. |

### Design coherence

The implementation follows the reduction design: NVIDIA is retained, OpenCode preserves only the two streaming overrides, the dead extension is removed, and no routing profile changed. The proposal, design, and task artifacts still mention historical `22`/`29` counts; they are superseded by the updated dynamic delta spec for acceptance and should be normalized only if archive policy requires artifact prose consistency.

### Issues

CRITICAL: None.

WARNING: The baseline HEAD advanced from `ae5b172` to `a4a5564` during verification due to an unrelated skill-only commit. The final A/B harness was rerun against `a4a5564`, whose provider baseline is unchanged.

SUGGESTION: Archive may update historical literal profile/model counts in proposal, design, and tasks to the same dynamic-baseline wording, but this is not a specification blocker.

### Verdict

PASS WITH WARNINGS. All six current scenarios have passed runtime evidence under the updated dynamic acceptance criteria.

Verified: Yes

Ready for Archive: Yes
```
