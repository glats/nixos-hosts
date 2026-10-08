# Tasks: Patch FreeRDP macOS display probe

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Unit 1 (patch + overlay) → Unit 2 (launcher), one PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Patch, adapter, overlay; probe values match | PR 1 | `nix build .#darwinConfigurations.macm5.pkgs.freerdp --no-link` + `diff OLD.mon NEW.mon` | Probe timing script, Spaces on, 3 displays | `overlays/darwin.nix` `patches` + `patches/freerdp/` |
| 2 | Launcher drops setenv block | PR 1 (2nd commit) | `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` | User green-button check (N/A for agent) | `darwin/home/remote-desktop.nix` |

## Phase 0: Preflight

- [x] 0.1 `git -C /Users/juan/.config/nix status -sb`; confirm `remote-desktop.nix` uncommitted diff is only the `CGGetActiveDisplayList` conditional, which is superseded and not committed. Verify: diff shows it.
- [x] 0.2 Confirm `openspec/changes/macm5-local-llm/` untouched. Verify: `git status -- openspec/changes/macm5-local-llm` empty.

## Phase 1: Unit 1 — Patch, adapter, overlay

- [x] 1.1 RED baseline: capture OLD (`/nix/store/39v8515j6nn4bpsjjnwpmgsxs48yz3bj-freerdp-3.30.0`, gcroot) with `env -u SDL_VIDEO_MAC_FULLSCREEN_SPACES`. Verify: gaps ~650 ms; `OLD.mon` saved.
- [x] 1.2 Create `patches/freerdp/sdl-macos-cmake.patch` (design adapter). Verify: hunks only in `client/SDL/SDL3/CMakeLists.txt`.
- [x] 1.3 Obtain upstream patch (PR #13564, SHA `dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2`, CMake excluded) via `fetchpatch` with `lib.fakeHash` (read `got:`). If the fetch fails with self-signed certificate: never use `--insecure`/`curlOptsList`; vendor as `patches/freerdp/sdl-macos-window-free-display-query.patch` with a header naming PR #13564 and the SHA. Verify: no CMake hunk; `grep -rn insecure overlays patches darwin` empty.
- [x] 1.4 Add freerdp `patches` to `overlays/darwin.nix` with drop-condition comment (remove once nixpkgs includes #13564; re-check at next bump). Verify: `nix fmt -- overlays/darwin.nix`; macm5 toplevel `drvPath` evaluates.
- [x] 1.5 Build freerdp (`NEW=$(nix build .#darwinConfigurations.macm5.pkgs.freerdp --no-link --print-out-paths)`). Verify: log shows `sdl_macos.mm` compiled; `otool -L $NEW/bin/sdl-freerdp | grep AppKit`. Failure → Phase 4 gate.
- [x] 1.6 Probe NEW with Spaces on → `NEW.mon`. Verify: low-ms gaps; `diff OLD.mon NEW.mon` IDENTICAL including notch `y`. Mismatch → Phase 4 gate.
- [x] 1.7 Commit unit 1 in English. Do not push.

## Phase 2: Unit 2 — Launcher (only after 1.6 green)

- [x] 2.1 `darwin/home/remote-desktop.nix`: remove whole comment and `displayCount`/`setenv` block; keep `<Carbon/Carbon.h>`. Verify: `nix fmt -- darwin/home/remote-desktop.nix`; grep for `SDL_VIDEO_MAC_FULLSCREEN_SPACES|CGGetActiveDisplayList` empty.
- [x] 2.2 Re-evaluate macm5 toplevel. Verify: `drvPath` evaluates.
- [x] 2.3 `strings` on built launcher. Verify: no `SDL_VIDEO_MAC_FULLSCREEN_SPACES`.
- [x] 2.4 Commit unit 2 in English. Do not push.

## Phase 3: User steps (agent stops)

- [ ] 3.1 Ask user to run `darwin-rebuild switch` on macm5. Agent MUST NOT switch.
- [ ] 3.2 User real-session check (`/workarea /w /h /smart-sizing`): green button enters native Space on 3 and 1 displays, no hopping. Verify: user confirms.
- [ ] 3.3 On user confirmation, push. Otherwise revert per rollback.

## Phase 4: Fallback (approach 4) — gated

- [ ] 4.1 Proceed only if 1.5 fails, hunk 4 needs fuzz > 2, or 1.6 differs. Record trigger.
- [ ] 4.2 Replace with vendored `patches/freerdp/*.patch` of `queryWithoutWindow` only (no `sdl_macos.*`, no notch inset); drop adapter if no `.mm`. Verify: build succeeds.
- [ ] 4.3 Rerun 1.6 and Phase 2. Verify: `diff OLD.mon NEW.mon` IDENTICAL; if notch `y` differs, stop and ask user.
