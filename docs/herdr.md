# Herdr: Multi-Agent Worktree Multiplexer

`herdr` is a terminal agent multiplexer that keeps each agent in its own git worktree and reports its live state (working, blocked, done) in the sidebar. It is declared in `shared/herdr.nix` and installed on all hosts (rog, thinkcentre, t14, macm5). The existing `code-work` tool is untouched; herdr is an independent tool for browsing the repo and bootstrapping parallel agent sessions.

## What Home Manager owns

- The `herdr` package (`pkgs/herdr`, upstream v0.9.3) via `home.packages`.
- `~/.config/herdr/config.toml` with `onboarding = false` and the default worktree directory `~/.herdr/worktrees`. The file is rewritten from the declarative content after every generation, so manual edits made inside herdr survive until the next switch and then revert to the declaration.
- The OpenCode integration files (see below).

The OpenCode plugin files are produced by running `herdr integration install opencode` against a throwaway HOME inside a build-time derivation (`shared/herdr.nix`), then copying its output:

- `~/.config/opencode/plugins/herdr-agent-state.js` — part of the managed plugins tree in `shared/opencode/runtime-config.nix`; reports agent state to herdr.
- `~/.config/opencode/herdr-tui-session.js` — TUI plugin, registered in `~/.config/opencode/tui.jsonc`.
- `~/.config/opencode/herdr-opencode/tui.js` — V2 TUI directory entrypoint, registered in `~/.config/opencode/cli.json` under `plugins: ["./herdr-opencode"]` next to the pre-existing `$schema` key.

Do not run `herdr integration install opencode` by hand: the OpenCode config tree is reconciled by `ai-assets-reconcile` and the imperative installer would collide with the managed files. Updating these files happens declaratively when the `herdr` package version changes.

## Daily flow

Start herdr from any shell by running `herdr`.

1. Start a feature. Open the repo row in the herdr sidebar and choose "New worktree", or run `herdr worktree create --branch feat-x --focus`. Herdr creates a git worktree under `~/.herdr/worktrees/<repo>/<branch>` and opens a workspace pane on it with focus.
2. Run `opencode` inside that worktree. Herdr monitors the session and the sidebar shows its live state: working, blocked (waiting on a permission or question), done.
3. Spawn more agents in parallel by creating more worktrees. Every workspace is an isolated checkout, so parallel branches never interleave edits.
4. Review from the main checkout with plain git: `git log feat-x`, `git diff main...feat-x`. Switch between workspaces with the workspace picker (prefix+w).
5. Close out a finished worktree from the main checkout: merge it (`git merge feat-x`), remove the checkout (`herdr worktree remove --workspace <ID>`; add `--force` to discard uncommitted changes), then delete the branch (`git branch -d feat-x`).

The first worktree creation in a repository may ask to trust it; confirm once (the `--trust-repository` flag is available for scripted creation). The onboarding wizard is disabled by the managed config.

## Check before switching

After editing the declarative config, run `herdr config check` (it also accepts your live file via `HERDR_CONFIG_PATH`) to verify the TOML parses before deploying a host switch.
